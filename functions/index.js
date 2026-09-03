const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { initializeApp } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const {
  getFirestore,
  FieldValue,
  Timestamp,
} = require("firebase-admin/firestore");

initializeApp();

const db = getFirestore();
const auth = getAuth();


// ============================================================
// COMMON ADMIN CHECK
// Supports:
// Admins/{uid}.role / Role == admin
// OR users/{uid}.role / Role == admin
// ============================================================

async function verifyAdmin(request) {
  if (!request.auth) {
    throw new HttpsError(
      "unauthenticated",
      "You must be logged in."
    );
  }

  const adminUid = request.auth.uid;

  const adminDoc = await db
    .collection("Admins")
    .doc(adminUid)
    .get();

  if (adminDoc.exists) {
    const adminData = adminDoc.data() || {};

    const adminRole = String(
      adminData.Role ||
      adminData.role ||
      ""
    ).toLowerCase();

    if (adminRole === "admin") {
      return adminUid;
    }
  }

  const userDoc = await db
    .collection("users")
    .doc(adminUid)
    .get();

  if (userDoc.exists) {
    const userData = userDoc.data() || {};

    const userRole = String(
      userData.role ||
      userData.Role ||
      ""
    ).toLowerCase();

    if (userRole === "admin") {
      return adminUid;
    }
  }

  throw new HttpsError(
    "permission-denied",
    "Only Admin can perform this action."
  );
}


// ============================================================
// COMMON COURIER CHECK
// ============================================================

async function verifyCourier(request) {
  if (!request.auth) {
    throw new HttpsError(
      "unauthenticated",
      "You must be logged in."
    );
  }

  const courierUid = request.auth.uid;

  const userDoc = await db
    .collection("users")
    .doc(courierUid)
    .get();

  if (!userDoc.exists) {
    throw new HttpsError(
      "permission-denied",
      "Courier account not found."
    );
  }

  const userData = userDoc.data() || {};

  const role = String(
    userData.role ||
    userData.Role ||
    ""
  ).toLowerCase();

  const active =
    userData.active !== false;

  if (role !== "courier") {
    throw new HttpsError(
      "permission-denied",
      "Courier permission required."
    );
  }

  if (!active) {
    throw new HttpsError(
      "permission-denied",
      "Courier account is inactive."
    );
  }

  return {
    uid: courierUid,
    name: String(
      userData.name ||
      userData.displayName ||
      ""
    ).trim(),
    phone: String(
      userData.phone ||
      ""
    ).trim(),
  };
}


// ============================================================
// ORDER STATUS NORMALIZATION
// ============================================================

function normalizeOrderStatus(value) {
  const raw = String(value || "")
    .trim()
    .toLowerCase();

  const map = {
    placed: "Placed",
    confirmed: "Confirmed",
    processing: "Processing",
    packed: "Packed",
    shipped: "Shipped",
    "picked by courier":
      "Picked by Courier",
    "out for delivery":
      "Out for Delivery",
    delivered: "Delivered",
    cancelled: "Cancelled",
  };

  return map[raw] || "";
}


// ============================================================
// APPEND STATUS HISTORY
// ============================================================

function buildStatusHistory(
  existingHistory,
  {
    status,
    previousStatus,
    updatedBy,
    updatedByUid,
    reason,
    courierId,
  }
) {
  const oldHistory =
    Array.isArray(existingHistory)
      ? existingHistory
      : [];

  const entry = {
    status,
    previousStatus:
      previousStatus || "",
    timestamp:
      Timestamp.now(),
    updatedBy,
    updatedByUid,
  };

  if (reason) {
    entry.reason = reason;
  }

  if (courierId) {
    entry.courierId = courierId;
  }

  return [
    ...oldHistory,
    entry,
  ];
}


// ============================================================
// CREATE COURIER ACCOUNT
// ============================================================

exports.createCourierAccount = onCall(
  {
    region: "asia-south1",
  },
  async (request) => {
    const adminUid =
      await verifyAdmin(request);

    const data = request.data || {};

    const name =
      String(data.name || "").trim();

    const email =
      String(data.email || "")
        .trim()
        .toLowerCase();

    const phone =
      String(data.phone || "").trim();

    const password =
      String(data.password || "");

    if (!name) {
      throw new HttpsError(
        "invalid-argument",
        "Courier name is required."
      );
    }

    if (!email) {
      throw new HttpsError(
        "invalid-argument",
        "Courier email is required."
      );
    }

    if (!password || password.length < 6) {
      throw new HttpsError(
        "invalid-argument",
        "Password must contain at least 6 characters."
      );
    }

    const emailRegex =
      /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

    if (!emailRegex.test(email)) {
      throw new HttpsError(
        "invalid-argument",
        "Invalid email address."
      );
    }

    try {
      await auth.getUserByEmail(email);

      throw new HttpsError(
        "already-exists",
        "A Firebase account already exists with this email."
      );
    } catch (error) {
      if (error instanceof HttpsError) {
        throw error;
      }

      if (error.code !== "auth/user-not-found") {
        throw new HttpsError(
          "internal",
          "Unable to verify courier email."
        );
      }
    }

    let courierUser;

    try {
      courierUser =
        await auth.createUser({
          email,
          password,
          displayName: name,
          emailVerified: false,
          disabled: false,
        });
    } catch (error) {
      console.error(
        "Courier Auth creation failed:",
        error
      );

      if (
        error.code ===
        "auth/email-already-exists"
      ) {
        throw new HttpsError(
          "already-exists",
          "Firebase account already exists."
        );
      }

      throw new HttpsError(
        "internal",
        "Unable to create courier account."
      );
    }

    const courierUid =
      courierUser.uid;

    try {
      const batch = db.batch();

      const userRef = db
        .collection("users")
        .doc(courierUid);

      batch.set(
        userRef,
        {
          uid: courierUid,
          name,
          email,
          phone,
          role: "courier",
          active: true,
          createdAt:
            FieldValue.serverTimestamp(),
          updatedAt:
            FieldValue.serverTimestamp(),
        },
        {
          merge: true,
        }
      );

      const courierRef = db
        .collection("couriers")
        .doc(courierUid);

      batch.set(
        courierRef,
        {
          uid: courierUid,
          name,
          email,
          phone,
          role: "courier",
          active: true,
          createdAt:
            FieldValue.serverTimestamp(),
          updatedAt:
            FieldValue.serverTimestamp(),
          createdBy: adminUid,
        },
        {
          merge: true,
        }
      );

      await batch.commit();
    } catch (error) {
      console.error(
        "Courier Firestore creation failed:",
        error
      );

      try {
        await auth.deleteUser(
          courierUid
        );
      } catch (deleteError) {
        console.error(
          "Courier rollback failed:",
          deleteError
        );
      }

      throw new HttpsError(
        "internal",
        "Courier account creation failed."
      );
    }

    return {
      success: true,
      uid: courierUid,
      name,
      email,
      phone,
      role: "courier",
      message:
        "Courier account created successfully.",
    };
  }
);


// ============================================================
// AUTHORIZE VENDOR
// Authorization = PENDING
// ============================================================

exports.authorizeVendor = onCall(
  {
    region: "asia-south1",
  },
  async (request) => {
    const adminUid =
      await verifyAdmin(request);

    const data = request.data || {};

    const targetUid =
      String(data.uid || "").trim();

    const targetEmail =
      String(data.email || "")
        .trim()
        .toLowerCase();

    let vendorUser;

    try {
      if (targetUid) {
        vendorUser =
          await auth.getUser(targetUid);
      } else if (targetEmail) {
        vendorUser =
          await auth.getUserByEmail(
            targetEmail
          );
      } else {
        throw new HttpsError(
          "invalid-argument",
          "Vendor UID or email is required."
        );
      }
    } catch (error) {
      if (error instanceof HttpsError) {
        throw error;
      }

      if (
        error.code ===
        "auth/user-not-found"
      ) {
        throw new HttpsError(
          "not-found",
          "User account not found."
        );
      }

      throw new HttpsError(
        "internal",
        "Unable to find user account."
      );
    }

    const vendorUid =
      vendorUser.uid;

    const userRef = db
      .collection("users")
      .doc(vendorUid);

    const vendorRef = db
      .collection("vendors")
      .doc(vendorUid);

    const [userDoc, vendorDoc] =
      await Promise.all([
        userRef.get(),
        vendorRef.get(),
      ]);

    const existingUserData =
      userDoc.exists
        ? userDoc.data() || {}
        : {};

    const existingVendorData =
      vendorDoc.exists
        ? vendorDoc.data() || {}
        : {};

    const existingRole =
      String(
        existingUserData.role ||
        existingUserData.Role ||
        existingVendorData.role ||
        ""
      ).toLowerCase();

    if (existingRole === "admin") {
      throw new HttpsError(
        "failed-precondition",
        "Admin account cannot be authorized as vendor."
      );
    }

    if (existingRole === "courier") {
      throw new HttpsError(
        "failed-precondition",
        "Courier account cannot be authorized as vendor."
      );
    }

    const vendorName =
      String(
        data.name ||
        existingUserData.name ||
        existingVendorData.name ||
        vendorUser.displayName ||
        ""
      ).trim();

    const vendorEmail =
      String(
        data.email ||
        existingUserData.email ||
        existingVendorData.email ||
        vendorUser.email ||
        ""
      )
        .trim()
        .toLowerCase();

    const vendorPhone =
      String(
        data.phone ||
        existingUserData.phone ||
        existingVendorData.phone ||
        ""
      ).trim();

    if (!vendorName) {
      throw new HttpsError(
        "invalid-argument",
        "Vendor name is required."
      );
    }

    if (!vendorEmail) {
      throw new HttpsError(
        "invalid-argument",
        "Vendor email is required."
      );
    }

    const batch = db.batch();

    batch.set(
      userRef,
      {
        uid: vendorUid,
        name: vendorName,
        email: vendorEmail,
        phone: vendorPhone,
        role: "vendor",
        vendorStatus: "pending",
        active: false,
        vendorAuthorizedAt:
          FieldValue.serverTimestamp(),
        vendorAuthorizedBy:
          adminUid,
        updatedAt:
          FieldValue.serverTimestamp(),
        ...(userDoc.exists
          ? {}
          : {
              createdAt:
                FieldValue.serverTimestamp(),
            }),
      },
      {
        merge: true,
      }
    );

    batch.set(
      vendorRef,
      {
        uid: vendorUid,
        name: vendorName,
        email: vendorEmail,
        phone: vendorPhone,
        role: "vendor",
        status: "pending",
        active: false,
        authorizedBy: adminUid,
        authorizedAt:
          FieldValue.serverTimestamp(),
        updatedAt:
          FieldValue.serverTimestamp(),
        ...(vendorDoc.exists
          ? {}
          : {
              createdAt:
                FieldValue.serverTimestamp(),
            }),
      },
      {
        merge: true,
      }
    );

    await batch.commit();

    return {
      success: true,
      uid: vendorUid,
      name: vendorName,
      email: vendorEmail,
      phone: vendorPhone,
      role: "vendor",
      vendorStatus: "pending",
      active: false,
      message:
        "Vendor added successfully. Documents verification pending.",
    };
  }
);


// ============================================================
// UPDATE VENDOR STATUS
// ============================================================

exports.updateVendorStatus = onCall(
  {
    region: "asia-south1",
  },
  async (request) => {
    const adminUid =
      await verifyAdmin(request);

    const data = request.data || {};

    const vendorUid =
      String(
        data.vendorUid || ""
      ).trim();

    const status =
      String(
        data.status || ""
      )
        .trim()
        .toLowerCase();

    const reason =
      String(
        data.reason || ""
      ).trim();

    if (!vendorUid) {
      throw new HttpsError(
        "invalid-argument",
        "Vendor UID is required."
      );
    }

    const allowedStatuses = [
      "pending",
      "approved",
      "rejected",
      "suspended",
    ];

    if (!allowedStatuses.includes(status)) {
      throw new HttpsError(
        "invalid-argument",
        "Invalid vendor status."
      );
    }

    const userRef = db
      .collection("users")
      .doc(vendorUid);

    const vendorRef = db
      .collection("vendors")
      .doc(vendorUid);

    const [userDoc, vendorDoc] =
      await Promise.all([
        userRef.get(),
        vendorRef.get(),
      ]);

    if (
      !userDoc.exists &&
      !vendorDoc.exists
    ) {
      throw new HttpsError(
        "not-found",
        "Vendor not found."
      );
    }

    const vendorData =
      vendorDoc.exists
        ? vendorDoc.data() || {}
        : {};

    if (status === "approved") {
      const documents =
        vendorData.documents || {};

      const requiredDocuments = [
        "pan",
        "aadhaar",
        "gst",
        "bank",
        "addressProof",
      ];

      const missingDocuments = [];
      const rejectedDocuments = [];

      for (
        const documentType
        of requiredDocuments
      ) {
        const document =
          documents[documentType] || {};

        const documentStatus =
          String(
            document.status || ""
          ).toLowerCase();

        if (
          documentStatus ===
          "rejected"
        ) {
          rejectedDocuments.push(
            documentType
          );
        } else if (
          documentStatus !==
          "verified"
        ) {
          missingDocuments.push(
            documentType
          );
        }
      }

      if (
        rejectedDocuments.length > 0
      ) {
        throw new HttpsError(
          "failed-precondition",
          "Vendor approval blocked. Rejected documents: " +
            rejectedDocuments.join(", ")
        );
      }

      if (
        missingDocuments.length > 0
      ) {
        throw new HttpsError(
          "failed-precondition",
          "Vendor approval blocked. Required documents not verified: " +
            missingDocuments.join(", ")
        );
      }
    }

    const isApproved =
      status === "approved";

    const batch = db.batch();

    batch.set(
      userRef,
      {
        role: "vendor",
        vendorStatus: status,
        active: isApproved,
        vendorStatusUpdatedAt:
          FieldValue.serverTimestamp(),
        vendorStatusUpdatedBy:
          adminUid,
        vendorStatusReason:
          reason,
        updatedAt:
          FieldValue.serverTimestamp(),
        ...(isApproved
          ? {
              vendorApprovedAt:
                FieldValue.serverTimestamp(),
              vendorApprovedBy:
                adminUid,
            }
          : {}),
      },
      {
        merge: true,
      }
    );

    batch.set(
      vendorRef,
      {
        role: "vendor",
        status,
        active: isApproved,
        statusUpdatedAt:
          FieldValue.serverTimestamp(),
        statusUpdatedBy:
          adminUid,
        statusReason:
          reason,
        updatedAt:
          FieldValue.serverTimestamp(),
        ...(isApproved
          ? {
              approvedAt:
                FieldValue.serverTimestamp(),
              approvedBy:
                adminUid,
            }
          : {}),
      },
      {
        merge: true,
      }
    );

    await batch.commit();

    return {
      success: true,
      vendorUid,
      status,
      active: isApproved,
      updatedBy: adminUid,
      message:
        isApproved
          ? "Vendor approved successfully."
          : "Vendor status updated successfully.",
    };
  }
);


// ============================================================
// UPDATE VENDOR DOCUMENT STATUS
// ============================================================

exports.updateVendorDocumentStatus = onCall(
  {
    region: "asia-south1",
  },
  async (request) => {
    const adminUid =
      await verifyAdmin(request);

    const data = request.data || {};

    const vendorUid =
      String(
        data.vendorUid || ""
      ).trim();

    const documentType =
      String(
        data.documentType || ""
      ).trim();

    const status =
      String(
        data.status || ""
      )
        .trim()
        .toLowerCase();

    const reason =
      String(
        data.reason || ""
      ).trim();

    if (!vendorUid) {
      throw new HttpsError(
        "invalid-argument",
        "Vendor UID is required."
      );
    }

    const allowedDocuments = [
      "pan",
      "aadhaar",
      "gst",
      "bank",
      "addressProof",
      "other",
    ];

    if (
      !allowedDocuments.includes(
        documentType
      )
    ) {
      throw new HttpsError(
        "invalid-argument",
        "Invalid document type."
      );
    }

    const allowedStatuses = [
      "pending",
      "verified",
      "rejected",
    ];

    if (
      !allowedStatuses.includes(status)
    ) {
      throw new HttpsError(
        "invalid-argument",
        "Invalid document status."
      );
    }

    const vendorRef = db
      .collection("vendors")
      .doc(vendorUid);

    const vendorDoc =
      await vendorRef.get();

    if (!vendorDoc.exists) {
      throw new HttpsError(
        "not-found",
        "Vendor not found."
      );
    }

    const vendorData =
      vendorDoc.data() || {};

    const existingDocuments =
      vendorData.documents || {};

    const existingDocument =
      existingDocuments[documentType] ||
      {};

    const updatedDocument = {
      ...existingDocument,
      status,
      verificationReason:
        reason,
      verifiedBy:
        adminUid,
      verifiedAt:
        FieldValue.serverTimestamp(),
      updatedAt:
        FieldValue.serverTimestamp(),
    };

    await vendorRef.set(
      {
        documents: {
          [documentType]:
            updatedDocument,
        },
        updatedAt:
          FieldValue.serverTimestamp(),
      },
      {
        merge: true,
      }
    );

    return {
      success: true,
      vendorUid,
      documentType,
      status,
      verifiedBy: adminUid,
      message:
        "Vendor document status updated successfully.",
    };
  }
);


// ============================================================
// ADMIN ORDER STATUS
//
// ADMIN FLOW:
//
// Placed
//   ↓
// Confirmed
//   ↓
// Processing
//   ↓
// Packed
//
// Shipped is handled separately by shipOrder.
// ============================================================

exports.updateOrderStatus = onCall(
  {
    region: "asia-south1",
  },
  async (request) => {
    const adminUid =
      await verifyAdmin(request);

    const data = request.data || {};

    const orderId =
      String(
        data.orderId || ""
      ).trim();

    const requestedStatus =
      String(
        data.newStatus ||
        data.status ||
        ""
      ).trim();

    if (!orderId) {
      throw new HttpsError(
        "invalid-argument",
        "Order ID is required."
      );
    }

    if (!requestedStatus) {
      throw new HttpsError(
        "invalid-argument",
        "New order status is required."
      );
    }

    const newStatus =
      normalizeOrderStatus(
        requestedStatus
      );

    if (
      ![
        "Confirmed",
        "Processing",
        "Packed",
      ].includes(newStatus)
    ) {
      throw new HttpsError(
        "invalid-argument",
        "Admin can only update status to Confirmed, Processing or Packed."
      );
    }

    const orderRef = db
      .collection("orders")
      .doc(orderId);

    let result = null;

    await db.runTransaction(
      async (transaction) => {
        const orderDoc =
          await transaction.get(
            orderRef
          );

        if (!orderDoc.exists) {
          throw new HttpsError(
            "not-found",
            "Order not found."
          );
        }

        const orderData =
          orderDoc.data() || {};

        const currentStatus =
          normalizeOrderStatus(
            orderData.orderStatus ||
            orderData.status
          );

        const allowedNextStatus = {
          Placed: "Confirmed",
          Confirmed: "Processing",
          Processing: "Packed",
        };

        const expectedNext =
          allowedNextStatus[
            currentStatus
          ];

        if (!expectedNext) {
          throw new HttpsError(
            "failed-precondition",
            "Order cannot be updated from its current status."
          );
        }

        if (
          newStatus !== expectedNext
        ) {
          throw new HttpsError(
            "failed-precondition",
            "Invalid status jump. Next allowed status is: " +
              expectedNext
          );
        }

        const newHistory =
          buildStatusHistory(
            orderData.statusHistory,
            {
              status: newStatus,
              previousStatus:
                currentStatus,
              updatedBy: "Admin",
              updatedByUid:
                adminUid,
            }
          );

        const updateData = {
          orderStatus:
            newStatus,
          status:
            newStatus,
          statusHistory:
            newHistory,
          updatedAt:
            FieldValue.serverTimestamp(),
        };

        if (
          newStatus === "Confirmed"
        ) {
          updateData.confirmedAt =
            FieldValue.serverTimestamp();
        }

        if (
          newStatus === "Processing"
        ) {
          updateData.processingAt =
            FieldValue.serverTimestamp();
        }

        if (
          newStatus === "Packed"
        ) {
          updateData.packedAt =
            FieldValue.serverTimestamp();
        }

        transaction.set(
          orderRef,
          updateData,
          {
            merge: true,
          }
        );

        result = {
          previousStatus:
            currentStatus,
          status:
            newStatus,
        };
      }
    );

    return {
      success: true,
      orderId,
      previousStatus:
        result.previousStatus,
      status:
        result.status,
      updatedBy: adminUid,
      message:
        "Order status updated successfully.",
    };
  }
);


// ============================================================
// SHIP ORDER - ADMIN ONLY
//
// ONLY:
// Packed → Shipped
//
// Requires:
// courierPartner
// trackingNumber
// ============================================================

exports.shipOrder = onCall(
  {
    region: "asia-south1",
  },
  async (request) => {
    const adminUid =
      await verifyAdmin(request);

    const data = request.data || {};

    const orderId =
      String(
        data.orderId || ""
      ).trim();

    const courierPartner =
      String(
        data.courierPartner || ""
      ).trim();

    const trackingNumber =
      String(
        data.trackingNumber || ""
      ).trim();

    const trackingUrl =
      String(
        data.trackingUrl || ""
      ).trim();

    const courierPersonName =
      String(
        data.courierPersonName || ""
      ).trim();

    const courierPhone =
      String(
        data.courierPhone || ""
      ).trim();

    if (!orderId) {
      throw new HttpsError(
        "invalid-argument",
        "Order ID is required."
      );
    }

    if (!courierPartner) {
      throw new HttpsError(
        "invalid-argument",
        "Courier partner is required."
      );
    }

    if (!trackingNumber) {
      throw new HttpsError(
        "invalid-argument",
        "Tracking number is required."
      );
    }

    const orderRef = db
      .collection("orders")
      .doc(orderId);

    let result = null;

    await db.runTransaction(
      async (transaction) => {
        const orderDoc =
          await transaction.get(
            orderRef
          );

        if (!orderDoc.exists) {
          throw new HttpsError(
            "not-found",
            "Order not found."
          );
        }

        const orderData =
          orderDoc.data() || {};

        const currentStatus =
          normalizeOrderStatus(
            orderData.orderStatus ||
            orderData.status
          );

        if (currentStatus !== "Packed") {
          throw new HttpsError(
            "failed-precondition",
            "Only Packed orders can be shipped."
          );
        }

        const newHistory =
          buildStatusHistory(
            orderData.statusHistory,
            {
              status: "Shipped",
              previousStatus:
                "Packed",
              updatedBy: "Admin",
              updatedByUid:
                adminUid,
            }
          );

        const updateData = {
          orderStatus:
            "Shipped",

          status:
            "Shipped",

          statusHistory:
            newHistory,

          courierPartner:
            courierPartner,

          trackingNumber:
            trackingNumber,

          trackingUrl:
            trackingUrl,

          trackingStatus:
            "Shipped",

          trackingEnabled:
            true,

          shippedAt:
            FieldValue.serverTimestamp(),

          shippedBy:
            adminUid,

          updatedAt:
            FieldValue.serverTimestamp(),
        };

        if (courierPersonName) {
          updateData.courierPersonName =
            courierPersonName;
        }

        if (courierPhone) {
          updateData.courierPhone =
            courierPhone;
        }

        transaction.set(
          orderRef,
          updateData,
          {
            merge: true,
          }
        );

        result = {
          previousStatus:
            "Packed",
          status:
            "Shipped",
        };
      }
    );

    return {
      success: true,
      orderId,
      previousStatus:
        result.previousStatus,
      status:
        result.status,
      courierPartner,
      trackingNumber,
      updatedBy: adminUid,
      message:
        "Order shipped successfully.",
    };
  }
);


// ============================================================
// CANCEL ORDER - ADMIN ONLY
//
// Allowed:
// Placed
// Confirmed
// Processing
//
// Not allowed:
// Packed
// Shipped
// Courier stages
// Delivered
// ============================================================

exports.cancelOrder = onCall(
  {
    region: "asia-south1",
  },
  async (request) => {
    const adminUid =
      await verifyAdmin(request);

    const data = request.data || {};

    const orderId =
      String(
        data.orderId || ""
      ).trim();

    const reason =
      String(
        data.reason || ""
      ).trim();

    if (!orderId) {
      throw new HttpsError(
        "invalid-argument",
        "Order ID is required."
      );
    }

    if (!reason) {
      throw new HttpsError(
        "invalid-argument",
        "Cancellation reason is required."
      );
    }

    const orderRef = db
      .collection("orders")
      .doc(orderId);

    await db.runTransaction(
      async (transaction) => {
        const orderDoc =
          await transaction.get(
            orderRef
          );

        if (!orderDoc.exists) {
          throw new HttpsError(
            "not-found",
            "Order not found."
          );
        }

        const orderData =
          orderDoc.data() || {};

        const currentStatus =
          normalizeOrderStatus(
            orderData.orderStatus ||
            orderData.status
          );

        const cancellableStatuses = [
          "Placed",
          "Confirmed",
          "Processing",
        ];

        if (
          !cancellableStatuses.includes(
            currentStatus
          )
        ) {
          throw new HttpsError(
            "failed-precondition",
            "Order cannot be cancelled at its current stage."
          );
        }

        const newHistory =
          buildStatusHistory(
            orderData.statusHistory,
            {
              status: "Cancelled",
              previousStatus:
                currentStatus,
              updatedBy: "Admin",
              updatedByUid:
                adminUid,
              reason,
            }
          );

        transaction.set(
          orderRef,
          {
            orderStatus:
              "Cancelled",

            status:
              "Cancelled",

            cancelled:
              true,

            cancellationReason:
              reason,

            cancelledAt:
              FieldValue.serverTimestamp(),

            cancelledBy:
              adminUid,

            statusHistory:
              newHistory,

            trackingEnabled:
              false,

            updatedAt:
              FieldValue.serverTimestamp(),
          },
          {
            merge: true,
          }
        );
      }
    );

    return {
      success: true,
      orderId,
      status: "Cancelled",
      cancelledBy: adminUid,
      message:
        "Order cancelled successfully.",
    };
  }
);


// ============================================================
// ASSIGN ORDER TO COURIER - ADMIN ONLY
//
// Allowed only:
// Shipped
//
// Does NOT change status.
// ============================================================

exports.assignOrderToCourier = onCall(
  {
    region: "asia-south1",
  },
  async (request) => {
    const adminUid =
      await verifyAdmin(request);

    const data = request.data || {};

    const orderId =
      String(
        data.orderId || ""
      ).trim();

    const courierId =
      String(
        data.courierId || ""
      ).trim();

    if (!orderId) {
      throw new HttpsError(
        "invalid-argument",
        "Order ID is required."
      );
    }

    if (!courierId) {
      throw new HttpsError(
        "invalid-argument",
        "Courier ID is required."
      );
    }

    const courierUserRef = db
      .collection("users")
      .doc(courierId);

    const courierRef = db
      .collection("couriers")
      .doc(courierId);

    const orderRef = db
      .collection("orders")
      .doc(orderId);

    const [
      courierUserDoc,
      courierDoc,
    ] = await Promise.all([
      courierUserRef.get(),
      courierRef.get(),
    ]);

    if (!courierUserDoc.exists) {
      throw new HttpsError(
        "not-found",
        "Courier user account not found."
      );
    }

    const courierUserData =
      courierUserDoc.data() || {};

    const courierRole =
      String(
        courierUserData.role ||
        courierUserData.Role ||
        ""
      ).toLowerCase();

    if (courierRole !== "courier") {
      throw new HttpsError(
        "failed-precondition",
        "Selected user is not a courier."
      );
    }

    if (
      courierUserData.active === false
    ) {
      throw new HttpsError(
        "failed-precondition",
        "Selected courier is inactive."
      );
    }

    let courierName =
      String(
        courierUserData.name ||
        ""
      ).trim();

    let courierPhone =
      String(
        courierUserData.phone ||
        ""
      ).trim();

    if (courierDoc.exists) {
      const courierData =
        courierDoc.data() || {};

      courierName =
        String(
          courierData.name ||
          courierName
        ).trim();

      courierPhone =
        String(
          courierData.phone ||
          courierPhone
        ).trim();
    }

    await db.runTransaction(
      async (transaction) => {
        const orderDoc =
          await transaction.get(
            orderRef
          );

        if (!orderDoc.exists) {
          throw new HttpsError(
            "not-found",
            "Order not found."
          );
        }

        const orderData =
          orderDoc.data() || {};

        const currentStatus =
          normalizeOrderStatus(
            orderData.orderStatus ||
            orderData.status
          );

        if (currentStatus !== "Shipped") {
          throw new HttpsError(
            "failed-precondition",
            "Courier can only be assigned to a Shipped order."
          );
        }

        const existingCourierId =
          String(
            orderData.courierId || ""
          ).trim();

        if (
          existingCourierId &&
          existingCourierId !== courierId
        ) {
          throw new HttpsError(
            "failed-precondition",
            "Order is already assigned to another courier."
          );
        }

        transaction.set(
          orderRef,
          {
            courierId,
            courierPersonName:
              courierName,
            courierPhone:
              courierPhone,
            courierAssignedAt:
              FieldValue.serverTimestamp(),
            courierAssignedBy:
              adminUid,
            updatedAt:
              FieldValue.serverTimestamp(),
          },
          {
            merge: true,
          }
        );
      }
    );

    return {
      success: true,
      orderId,
      courierId,
      courierPersonName:
        courierName,
      courierPhone,
      assignedBy:
        adminUid,
      message:
        "Courier assigned successfully.",
    };
  }
);


// ============================================================
// UPDATE COURIER ORDER STATUS
//
// Shipped
//    ↓
// Picked by Courier
//    ↓
// Out for Delivery
//    ↓
// Delivered
// ============================================================

exports.updateCourierOrderStatus = onCall(
  {
    region: "asia-south1",
  },
  async (request) => {
    const courier =
      await verifyCourier(request);

    const data = request.data || {};

    const orderId =
      String(
        data.orderId || ""
      ).trim();

    const requestedStatus =
      String(
        data.status || ""
      ).trim();

    if (!orderId) {
      throw new HttpsError(
        "invalid-argument",
        "Order ID is required."
      );
    }

    if (!requestedStatus) {
      throw new HttpsError(
        "invalid-argument",
        "Order status is required."
      );
    }

    const newStatus =
      normalizeOrderStatus(
        requestedStatus
      );

    if (
      ![
        "Picked by Courier",
        "Out for Delivery",
        "Delivered",
      ].includes(newStatus)
    ) {
      throw new HttpsError(
        "invalid-argument",
        "Invalid courier status."
      );
    }

    const orderRef = db
      .collection("orders")
      .doc(orderId);

    let result = null;

    await db.runTransaction(
      async (transaction) => {
        const orderDoc =
          await transaction.get(
            orderRef
          );

        if (!orderDoc.exists) {
          throw new HttpsError(
            "not-found",
            "Order not found."
          );
        }

        const orderData =
          orderDoc.data() || {};

        const currentStatus =
          normalizeOrderStatus(
            orderData.orderStatus ||
            orderData.status
          );

        const assignedCourierId =
          String(
            orderData.courierId || ""
          ).trim();

        if (!assignedCourierId) {
          throw new HttpsError(
            "failed-precondition",
            "Order has not been assigned to a courier."
          );
        }

        if (
          assignedCourierId !==
          courier.uid
        ) {
          throw new HttpsError(
            "permission-denied",
            "This order is assigned to another courier."
          );
        }

        const allowedNextStatus = {
          Shipped:
            "Picked by Courier",

          "Picked by Courier":
            "Out for Delivery",

          "Out for Delivery":
            "Delivered",
        };

        const expectedNext =
          allowedNextStatus[
            currentStatus
          ];

        if (!expectedNext) {
          throw new HttpsError(
            "failed-precondition",
            "Courier cannot update the order from its current status."
          );
        }

        if (
          newStatus !== expectedNext
        ) {
          throw new HttpsError(
            "failed-precondition",
            "Invalid status jump. Next allowed status is: " +
              expectedNext
          );
        }

        const newHistory =
          buildStatusHistory(
            orderData.statusHistory,
            {
              status: newStatus,
              previousStatus:
                currentStatus,
              updatedBy:
                "Courier",
              updatedByUid:
                courier.uid,
              courierId:
                courier.uid,
            }
          );

        const updateData = {
          orderStatus:
            newStatus,

          status:
            newStatus,

          trackingStatus:
            newStatus,

          statusHistory:
            newHistory,

          updatedAt:
            FieldValue.serverTimestamp(),
        };

        if (
          newStatus ===
          "Picked by Courier"
        ) {
          updateData.courierPickedAt =
            FieldValue.serverTimestamp();
        }

        if (
          newStatus ===
          "Out for Delivery"
        ) {
          updateData.outForDeliveryAt =
            FieldValue.serverTimestamp();
        }

        if (
          newStatus ===
          "Delivered"
        ) {
          updateData.deliveredAt =
            FieldValue.serverTimestamp();

          updateData.deliveryCompletedBy =
            courier.uid;

          updateData.deliveryCompletedAt =
            FieldValue.serverTimestamp();

          updateData.trackingEnabled =
            false;

          updateData.deliveryStatus =
            "Delivered";
        }

        transaction.set(
          orderRef,
          updateData,
          {
            merge: true,
          }
        );

        result = {
          previousStatus:
            currentStatus,
          status:
            newStatus,
        };
      }
    );

    return {
      success: true,
      orderId,
      previousStatus:
        result.previousStatus,
      status:
        result.status,
      courierId:
        courier.uid,
      message:
        "Order status updated successfully.",
    };
  }
);
