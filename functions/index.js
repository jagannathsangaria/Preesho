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

  if (!adminDoc.exists) {
    throw new HttpsError(
      "permission-denied",
      "Only Admin can perform this action."
    );
  }

  const adminData = adminDoc.data() || {};

  const adminRole = String(
    adminData.Role ||
    adminData.role ||
    ""
  ).toLowerCase();

  if (adminRole !== "admin") {
    throw new HttpsError(
      "permission-denied",
      "Admin permission required."
    );
  }

  return adminUid;
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
    name: String(userData.name || "").trim(),
    phone: String(userData.phone || "").trim(),
  };
}


// ============================================================
// CREATE COURIER ACCOUNT
// ============================================================

exports.createCourierAccount = onCall(
  {
    region: "asia-south1",
  },
  async (request) => {
    const adminUid = await verifyAdmin(request);

    const data = request.data || {};

    const name = String(data.name || "").trim();
    const email = String(data.email || "")
      .trim()
      .toLowerCase();
    const phone = String(data.phone || "").trim();
    const password = String(data.password || "");

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
      courierUser = await auth.createUser({
        email: email,
        password: password,
        displayName: name,
        emailVerified: false,
        disabled: false,
      });
    } catch (error) {
      console.error(
        "Courier Auth creation failed:",
        error
      );

      if (error.code === "auth/email-already-exists") {
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

    const courierUid = courierUser.uid;

    try {
      const batch = db.batch();

      const userRef = db
        .collection("users")
        .doc(courierUid);

      batch.set(userRef, {
        uid: courierUid,
        name: name,
        email: email,
        phone: phone,
        role: "courier",
        active: true,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });

      const courierRef = db
        .collection("couriers")
        .doc(courierUid);

      batch.set(courierRef, {
        uid: courierUid,
        name: name,
        email: email,
        phone: phone,
        role: "courier",
        active: true,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        createdBy: adminUid,
      });

      await batch.commit();
    } catch (error) {
      console.error(
        "Courier Firestore creation failed:",
        error
      );

      try {
        await auth.deleteUser(courierUid);
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
      name: name,
      email: email,
      phone: phone,
      role: "courier",
      message: "Courier account created successfully.",
    };
  }
);


// ============================================================
// AUTHORIZE VENDOR
// IMPORTANT:
// Authorization = PENDING only.
// It does NOT approve the vendor.
// ============================================================

exports.authorizeVendor = onCall(
  {
    region: "asia-south1",
  },
  async (request) => {
    const adminUid = await verifyAdmin(request);

    const data = request.data || {};

    const targetUid = String(
      data.uid || ""
    ).trim();

    const targetEmail = String(
      data.email || ""
    ).trim().toLowerCase();

    let vendorUser;

    try {
      if (targetUid) {
        vendorUser = await auth.getUser(targetUid);
      } else if (targetEmail) {
        vendorUser = await auth.getUserByEmail(targetEmail);
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

      if (error.code === "auth/user-not-found") {
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

    const vendorUid = vendorUser.uid;

    const userRef = db
      .collection("users")
      .doc(vendorUid);

    const vendorRef = db
      .collection("vendors")
      .doc(vendorUid);

    const [userDoc, vendorDoc] = await Promise.all([
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

    const existingRole = String(
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

    const vendorName = String(
      data.name ||
      existingUserData.name ||
      existingVendorData.name ||
      vendorUser.displayName ||
      ""
    ).trim();

    const vendorEmail = String(
      data.email ||
      existingUserData.email ||
      existingVendorData.email ||
      vendorUser.email ||
      ""
    ).trim().toLowerCase();

    const vendorPhone = String(
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

    try {
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
          vendorAuthorizedBy: adminUid,
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
    } catch (error) {
      console.error(
        "Vendor authorization failed:",
        error
      );

      throw new HttpsError(
        "internal",
        "Unable to authorize vendor."
      );
    }

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
// UPDATE VENDOR STATUS - ADMIN ONLY
// ============================================================

exports.updateVendorStatus = onCall(
  {
    region: "asia-south1",
  },
  async (request) => {
    const adminUid = await verifyAdmin(request);

    const data = request.data || {};

    const vendorUid = String(
      data.vendorUid || ""
    ).trim();

    const status = String(
      data.status || ""
    ).trim().toLowerCase();

    const reason = String(
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

    const [userDoc, vendorDoc] = await Promise.all([
      userRef.get(),
      vendorRef.get(),
    ]);

    if (!userDoc.exists && !vendorDoc.exists) {
      throw new HttpsError(
        "not-found",
        "Vendor not found."
      );
    }

    const vendorData =
      vendorDoc.exists
        ? vendorDoc.data() || {}
        : {};

    // ----------------------------------------------------------
    // FINAL APPROVAL DOCUMENT CHECK
    // ----------------------------------------------------------

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

      for (const documentType of requiredDocuments) {
        const document =
          documents[documentType] || {};

        const documentStatus =
          String(
            document.status || ""
          ).toLowerCase();

        if (documentStatus === "rejected") {
          rejectedDocuments.push(
            documentType
          );
        } else if (
          documentStatus !== "verified"
        ) {
          missingDocuments.push(
            documentType
          );
        }
      }

      if (rejectedDocuments.length > 0) {
        throw new HttpsError(
          "failed-precondition",
          "Vendor approval blocked. Rejected documents: " +
            rejectedDocuments.join(", ")
        );
      }

      if (missingDocuments.length > 0) {
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
        status: status,
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
      vendorUid: vendorUid,
      status: status,
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
// UPDATE VENDOR DOCUMENT STATUS - ADMIN ONLY
// ============================================================

exports.updateVendorDocumentStatus = onCall(
  {
    region: "asia-south1",
  },
  async (request) => {
    const adminUid = await verifyAdmin(request);

    const data = request.data || {};

    const vendorUid = String(
      data.vendorUid || ""
    ).trim();

    const documentType = String(
      data.documentType || ""
    ).trim();

    const status = String(
      data.status || ""
    ).trim().toLowerCase();

    const reason = String(
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

    if (!allowedDocuments.includes(documentType)) {
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

    if (!allowedStatuses.includes(status)) {
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
      existingDocuments[documentType] || {};

    const updatedDocument = {
      ...existingDocument,

      status: status,

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
      vendorUid: vendorUid,
      documentType: documentType,
      status: status,
      verifiedBy: adminUid,
      message:
        "Vendor document status updated successfully.",
    };
  }
);


// ============================================================
// ASSIGN ORDER TO COURIER - ADMIN ONLY
//
// Allowed only when:
// Shipped
//
// This does NOT change order status.
// It only assigns the courier.
// ============================================================

exports.assignOrderToCourier = onCall(
  {
    region: "asia-south1",
  },
  async (request) => {
    const adminUid = await verifyAdmin(request);

    const data = request.data || {};

    const orderId = String(
      data.orderId || ""
    ).trim();

    const courierId = String(
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

    const [courierUserDoc, courierDoc] =
      await Promise.all([
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

    const courierRole = String(
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

    if (courierUserData.active === false) {
      throw new HttpsError(
        "failed-precondition",
        "Selected courier is inactive."
      );
    }

    let courierName =
      String(
        courierUserData.name || ""
      ).trim();

    let courierPhone =
      String(
        courierUserData.phone || ""
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
          await transaction.get(orderRef);

        if (!orderDoc.exists) {
          throw new HttpsError(
            "not-found",
            "Order not found."
          );
        }

        const orderData =
          orderDoc.data() || {};

        const currentStatus = String(
          orderData.orderStatus ||
          orderData.status ||
          ""
        ).trim().toLowerCase();

        if (currentStatus !== "shipped") {
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
            courierId: courierId,
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
      orderId: orderId,
      courierId: courierId,
      courierPersonName: courierName,
      courierPhone: courierPhone,
      assignedBy: adminUid,
      message:
        "Courier assigned successfully.",
    };
  }
);


// ============================================================
// UPDATE COURIER ORDER STATUS
//
// STRICT FLOW:
//
// Shipped
//    ↓
// Picked by Courier
//    ↓
// Out for Delivery
//    ↓
// Delivered
//
// Courier cannot jump stages.
// Courier cannot update another courier's order.
// ============================================================

exports.updateCourierOrderStatus = onCall(
  {
    region: "asia-south1",
  },
  async (request) => {
    const courier = await verifyCourier(request);

    const data = request.data || {};

    const orderId = String(
      data.orderId || ""
    ).trim();

    const requestedStatus = String(
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

    const normalizedRequestedStatus =
      requestedStatus.toLowerCase();

    const statusMap = {
      "shipped": "Shipped",
      "picked by courier":
        "Picked by Courier",
      "out for delivery":
        "Out for Delivery",
      "delivered": "Delivered",
    };

    const newStatus =
      statusMap[
        normalizedRequestedStatus
      ];

    if (!newStatus) {
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
          await transaction.get(orderRef);

        if (!orderDoc.exists) {
          throw new HttpsError(
            "not-found",
            "Order not found."
          );
        }

        const orderData =
          orderDoc.data() || {};

        const currentStatusRaw =
          String(
            orderData.orderStatus ||
            orderData.status ||
            ""
          ).trim().toLowerCase();

        const statusNormalization = {
          "shipped": "Shipped",
          "picked by courier":
            "Picked by Courier",
          "out for delivery":
            "Out for Delivery",
          "delivered": "Delivered",
          "placed": "Placed",
          "confirmed": "Confirmed",
          "processing": "Processing",
          "packed": "Packed",
        };

        const currentStatus =
          statusNormalization[
            currentStatusRaw
          ] || currentStatusRaw;

        // ------------------------------------------------------
        // COURIER OWNERSHIP CHECK
        // ------------------------------------------------------

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
          assignedCourierId !== courier.uid
        ) {
          throw new HttpsError(
            "permission-denied",
            "This order is assigned to another courier."
          );
        }

        // ------------------------------------------------------
        // STRICT NEXT STATUS CHECK
        // ------------------------------------------------------

        const allowedNextStatus = {
          "Shipped":
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

        // ------------------------------------------------------
        // STATUS HISTORY
        // ------------------------------------------------------

        const oldHistory =
          Array.isArray(
            orderData.statusHistory
          )
            ? orderData.statusHistory
            : [];

        const historyEntry = {
          status: newStatus,
          previousStatus:
            currentStatus,
          timestamp:
            Timestamp.now(),
          updatedBy:
            "Courier",
          updatedByUid:
            courier.uid,
          courierId:
            courier.uid,
        };

        const newHistory = [
          ...oldHistory,
          historyEntry,
        ];

        // ------------------------------------------------------
        // COMMON UPDATE
        // ------------------------------------------------------

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

        // ------------------------------------------------------
        // STAGE TIMESTAMPS
        // ------------------------------------------------------

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
      orderId: orderId,
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
