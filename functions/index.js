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
// COMMON NORMALIZERS
// ============================================================

function normalizeRole(value) {
  return String(value || "")
    .trim()
    .toLowerCase();
}

function normalizeStatus(value) {
  return String(value || "")
    .trim()
    .toLowerCase()
    .replace(/\s+/g, "_");
}

function cleanString(value) {
  return String(value || "").trim();
}


// ============================================================
// COMMON ADMIN CHECK
//
// Supports:
//
// Admins/{uid}.role / Role == admin
// OR
// users/{uid}.role / Role == admin
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

    const adminRole = normalizeRole(
      adminData.Role || adminData.role
    );

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

    const userRole = normalizeRole(
      userData.role || userData.Role
    );

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
//
// SECURITY REQUIREMENTS:
//
// users/{uid}
// couriers/{uid}
//
// BOTH must have:
//
// role = courier
// status = approved
// active = true
// approvedByAdmin = true
//
// This function is used by courier-only backend operations.
// ============================================================

async function verifyCourier(request) {
  if (!request.auth) {
    throw new HttpsError(
      "unauthenticated",
      "You must be logged in."
    );
  }

  const courierUid = request.auth.uid;

  const userRef = db
    .collection("users")
    .doc(courierUid);

  const courierRef = db
    .collection("couriers")
    .doc(courierUid);

  const [userDoc, courierDoc] = await Promise.all([
    userRef.get(),
    courierRef.get(),
  ]);

  if (!userDoc.exists) {
    throw new HttpsError(
      "permission-denied",
      "Courier account not found."
    );
  }

  if (!courierDoc.exists) {
    throw new HttpsError(
      "permission-denied",
      "Courier profile not found."
    );
  }

  const userData = userDoc.data() || {};
  const courierData = courierDoc.data() || {};

  const userRole = normalizeRole(
    userData.role || userData.Role
  );

  const courierRole = normalizeRole(
    courierData.role || courierData.Role
  );

  if (
    userRole !== "courier" ||
    courierRole !== "courier"
  ) {
    throw new HttpsError(
      "permission-denied",
      "Courier permission required."
    );
  }

  const userStatus = normalizeStatus(
    userData.status ||
    userData.registrationStatus
  );

  const courierStatus = normalizeStatus(
    courierData.status ||
    courierData.registrationStatus
  );

  if (userStatus !== "approved") {
    throw new HttpsError(
      "permission-denied",
      "Courier account is not approved."
    );
  }

  if (courierStatus !== "approved") {
    throw new HttpsError(
      "permission-denied",
      "Courier profile is not approved."
    );
  }

  if (
    userData.active !== true ||
    courierData.active !== true
  ) {
    throw new HttpsError(
      "permission-denied",
      "Courier account is inactive."
    );
  }

  if (
    userData.approvedByAdmin !== true ||
    courierData.approvedByAdmin !== true
  ) {
    throw new HttpsError(
      "permission-denied",
      "Courier has not been approved by Admin."
    );
  }

  return {
    uid: courierUid,

    name: cleanString(
      courierData.name ||
      userData.name ||
      userData.displayName ||
      ""
    ),

    phone: cleanString(
      courierData.phone ||
      userData.phone ||
      ""
    ),

    email: cleanString(
      courierData.email ||
      userData.email ||
      ""
    ).toLowerCase(),
  };
}


// ============================================================
// COURIER PROFILE VALIDATION
//
// Used by Admin assignment.
// Target courier UID is supplied by Admin,
// therefore we do NOT trust the client data.
// We read the actual Firestore profiles.
// ============================================================

async function verifyTargetCourier(courierId) {
  const userRef = db
    .collection("users")
    .doc(courierId);

  const courierRef = db
    .collection("couriers")
    .doc(courierId);

  const [userDoc, courierDoc] = await Promise.all([
    userRef.get(),
    courierRef.get(),
  ]);

  if (!userDoc.exists) {
    throw new HttpsError(
      "not-found",
      "Courier user account not found."
    );
  }

  if (!courierDoc.exists) {
    throw new HttpsError(
      "not-found",
      "Courier profile not found."
    );
  }

  const userData = userDoc.data() || {};
  const courierData = courierDoc.data() || {};

  const userRole = normalizeRole(
    userData.role || userData.Role
  );

  const courierRole = normalizeRole(
    courierData.role || courierData.Role
  );

  if (
    userRole !== "courier" ||
    courierRole !== "courier"
  ) {
    throw new HttpsError(
      "failed-precondition",
      "Selected user is not a valid courier."
    );
  }

  const userStatus = normalizeStatus(
    userData.status ||
    userData.registrationStatus
  );

  const courierStatus = normalizeStatus(
    courierData.status ||
    courierData.registrationStatus
  );

  if (userStatus !== "approved") {
    throw new HttpsError(
      "failed-precondition",
      "Courier is not approved in users profile."
    );
  }

  if (courierStatus !== "approved") {
    throw new HttpsError(
      "failed-precondition",
      "Courier is not approved in courier profile."
    );
  }

  if (
    userData.active !== true ||
    courierData.active !== true
  ) {
    throw new HttpsError(
      "failed-precondition",
      "Selected courier is inactive."
    );
  }

  if (
    userData.approvedByAdmin !== true ||
    courierData.approvedByAdmin !== true
  ) {
    throw new HttpsError(
      "failed-precondition",
      "Courier has not been approved by Admin."
    );
  }

  return {
    uid: courierId,

    name: cleanString(
      courierData.name ||
      userData.name ||
      userData.displayName ||
      ""
    ),

    phone: cleanString(
      courierData.phone ||
      userData.phone ||
      ""
    ),

    email: cleanString(
      courierData.email ||
      userData.email ||
      ""
    ).toLowerCase(),
  };
}


// ============================================================
// REQUIRED VENDOR DOCUMENT CHECK
// ============================================================

function getVendorDocumentVerification(vendorData) {
  const documents = vendorData.documents || {};

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
    const document = documents[documentType] || {};

    const documentStatus = normalizeRole(
      document.status
    );

    if (documentStatus === "rejected") {
      rejectedDocuments.push(documentType);
    } else if (documentStatus !== "verified") {
      missingDocuments.push(documentType);
    }
  }

  return {
    allVerified:
      missingDocuments.length === 0 &&
      rejectedDocuments.length === 0,

    missingDocuments,
    rejectedDocuments,
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
    "picked by courier": "Picked by Courier",
    "out for delivery": "Out for Delivery",
    delivered: "Delivered",
    cancelled: "Cancelled",
  };

  return map[raw] || "";
}


// ============================================================
// STATUS HISTORY
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
    previousStatus: previousStatus || "",
    timestamp: Timestamp.now(),
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
// CREATE COURIER ACCOUNT - ADMIN
// ============================================================

exports.createCourierAccount = onCall(
  {
    region: "asia-south1",
  },
  async (request) => {
    const adminUid = await verifyAdmin(request);

    const data = request.data || {};

    const name = cleanString(data.name);

    const email = cleanString(data.email)
      .toLowerCase();

    const phone = cleanString(data.phone);

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

      if (
        error.code !==
        "auth/user-not-found"
      ) {
        throw new HttpsError(
          "internal",
          "Unable to verify courier email."
        );
      }
    }

    let courierUser;

    try {
      courierUser = await auth.createUser({
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

    const courierUid = courierUser.uid;

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

          status: "pending_documents",

          registrationStatus:
            "pending_documents",

          active: false,

          approvedByAdmin: false,

          documentsSubmitted: false,

          createdAt:
            FieldValue.serverTimestamp(),

          updatedAt:
            FieldValue.serverTimestamp(),
        },
        { merge: true }
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

          status: "pending_documents",

          registrationStatus:
            "pending_documents",

          active: false,

          approvedByAdmin: false,

          documentsSubmitted: false,

          documents: {},

          createdAt:
            FieldValue.serverTimestamp(),

          updatedAt:
            FieldValue.serverTimestamp(),

          createdBy: adminUid,
        },
        { merge: true }
      );

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
      name,
      email,
      phone,
      role: "courier",

      status: "pending_documents",

      active: false,

      approvedByAdmin: false,

      message:
        "Courier account created. Documents and Admin approval are required.",
    };
  }
);


// ============================================================
// AUTHORIZE VENDOR
// ============================================================

exports.authorizeVendor = onCall(
  {
    region: "asia-south1",
  },
  async (request) => {
    const adminUid = await verifyAdmin(request);

    const data = request.data || {};

    const targetUid = cleanString(data.uid);

    const targetEmail = cleanString(data.email)
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

    const vendorUid = vendorUser.uid;

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

    const existingRole = normalizeRole(
      existingUserData.role ||
      existingUserData.Role ||
      existingVendorData.role
    );

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

    const vendorName = cleanString(
      data.name ||
      existingUserData.name ||
      existingVendorData.name ||
      vendorUser.displayName
    );

    const vendorEmail = cleanString(
      data.email ||
      existingUserData.email ||
      existingVendorData.email ||
      vendorUser.email
    ).toLowerCase();

    const vendorPhone = cleanString(
      data.phone ||
      existingUserData.phone ||
      existingVendorData.phone
    );

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

        vendorStatus:
          "pending_documents",

        status:
          "pending_documents",

        active: false,

        approvedByAdmin: false,

        updatedAt:
          FieldValue.serverTimestamp(),

        vendorAuthorizedAt:
          FieldValue.serverTimestamp(),

        vendorAuthorizedBy:
          adminUid,

        ...(userDoc.exists
          ? {}
          : {
              createdAt:
                FieldValue.serverTimestamp(),
            }),
      },
      { merge: true }
    );

    batch.set(
      vendorRef,
      {
        uid: vendorUid,
        name: vendorName,
        email: vendorEmail,
        phone: vendorPhone,

        role: "vendor",

        status:
          "pending_documents",

        active: false,

        approvedByAdmin: false,

        documentsSubmitted:
          existingVendorData.documentsSubmitted === true,

        authorizedBy: adminUid,

        authorizedAt:
          FieldValue.serverTimestamp(),

        updatedAt:
          FieldValue.serverTimestamp(),

        ...(vendorDoc.exists
          ? {}
          : {
              documents: {},
              createdAt:
                FieldValue.serverTimestamp(),
            }),
      },
      { merge: true }
    );

    await batch.commit();

    return {
      success: true,
      uid: vendorUid,
      name: vendorName,
      email: vendorEmail,
      phone: vendorPhone,
      role: "vendor",

      vendorStatus:
        "pending_documents",

      status:
        "pending_documents",

      active: false,

      approvedByAdmin: false,

      message:
        "Vendor added. Documents and Admin approval are required.",
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
    const adminUid =
      await verifyAdmin(request);

    const data = request.data || {};

    const vendorUid =
      cleanString(data.vendorUid);

    const status =
      normalizeStatus(data.status);

    const reason =
      cleanString(data.reason);

    if (!vendorUid) {
      throw new HttpsError(
        "invalid-argument",
        "Vendor UID is required."
      );
    }

    const allowedStatuses = [
      "pending",
      "pending_documents",
      "pending_approval",
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

    const userData =
      userDoc.exists
        ? userDoc.data() || {}
        : {};

    const vendorData =
      vendorDoc.exists
        ? vendorDoc.data() || {}
        : {};

    const userRole =
      normalizeRole(
        userData.role ||
        userData.Role
      );

    const vendorRole =
      normalizeRole(
        vendorData.role ||
        vendorData.Role
      );

    if (
      userRole &&
      userRole !== "vendor"
    ) {
      throw new HttpsError(
        "failed-precondition",
        "Selected account is not a vendor."
      );
    }

    if (
      vendorRole &&
      vendorRole !== "vendor"
    ) {
      throw new HttpsError(
        "failed-precondition",
        "Vendor profile role is invalid."
      );
    }

    if (status === "approved") {
      if (!userDoc.exists) {
        throw new HttpsError(
          "failed-precondition",
          "Vendor user profile not found."
        );
      }

      if (!vendorDoc.exists) {
        throw new HttpsError(
          "failed-precondition",
          "Vendor profile not found."
        );
      }

      if (
        userRole !== "vendor" ||
        vendorRole !== "vendor"
      ) {
        throw new HttpsError(
          "failed-precondition",
          "Vendor role verification failed."
        );
      }

      if (
        vendorData.documentsSubmitted !== true
      ) {
        throw new HttpsError(
          "failed-precondition",
          "Vendor has not submitted documents for Admin approval."
        );
      }

      const verification =
        getVendorDocumentVerification(
          vendorData
        );

      if (
        verification.rejectedDocuments.length > 0
      ) {
        throw new HttpsError(
          "failed-precondition",
          "Vendor approval blocked. Rejected documents: " +
            verification.rejectedDocuments.join(", ")
        );
      }

      if (
        verification.missingDocuments.length > 0
      ) {
        throw new HttpsError(
          "failed-precondition",
          "Vendor approval blocked. Required documents not verified: " +
            verification.missingDocuments.join(", ")
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

        status:
          isApproved
            ? "approved"
            : status,

        vendorStatus:
          status,

        active:
          isApproved,

        approvedByAdmin:
          isApproved,

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
      { merge: true }
    );

    batch.set(
      vendorRef,
      {
        role: "vendor",

        status:
          status,

        active:
          isApproved,

        approvedByAdmin:
          isApproved,

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
      { merge: true }
    );

    await batch.commit();

    return {
      success: true,
      vendorUid,
      status,

      active:
        isApproved,

      approvedByAdmin:
        isApproved,

      updatedBy:
        adminUid,

      message:
        isApproved
          ? "Vendor approved successfully."
          : "Vendor status updated successfully.",
    };
  }
);


// ============================================================
// UPDATE VENDOR DOCUMENT STATUS
// ADMIN ONLY
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
      cleanString(data.vendorUid);

    const documentType =
      cleanString(data.documentType);

    const status =
      normalizeRole(data.status);

    const reason =
      cleanString(data.reason);

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
      existingDocuments[documentType] || {};

    const updatedDocument = {
      ...existingDocument,

      status,

      verificationReason:
        reason,

      rejectionReason:
        status === "rejected"
          ? reason
          : "",

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
      { merge: true }
    );

    return {
      success: true,
      vendorUid,
      documentType,
      status,
      verifiedBy:
        adminUid,

      message:
        "Vendor document status updated successfully.",
    };
  }
);


// ============================================================
// ADMIN ORDER STATUS
//
// Placed
//   ↓
// Confirmed
//   ↓
// Processing
//   ↓
// Packed
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
      cleanString(data.orderId);

    const requestedStatus =
      cleanString(
        data.newStatus ||
        data.status
      );

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

        if (newStatus === "Confirmed") {
          updateData.confirmedAt =
            FieldValue.serverTimestamp();
        }

        if (newStatus === "Processing") {
          updateData.processingAt =
            FieldValue.serverTimestamp();
        }

        if (newStatus === "Packed") {
          updateData.packedAt =
            FieldValue.serverTimestamp();
        }

        transaction.set(
          orderRef,
          updateData,
          { merge: true }
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

      updatedBy:
        adminUid,

      message:
        "Order status updated successfully.",
    };
  }
);


// ============================================================
// SHIP ORDER - ADMIN ONLY
//
// Packed → Shipped
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
      cleanString(data.orderId);

    const courierPartner =
      cleanString(data.courierPartner);

    const trackingNumber =
      cleanString(data.trackingNumber);

    const trackingUrl =
      cleanString(data.trackingUrl);

    const courierPersonName =
      cleanString(data.courierPersonName);

    const courierPhone =
      cleanString(data.courierPhone);

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
              previousStatus: "Packed",
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

          courierPartner,

          trackingNumber,

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
          { merge: true }
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

      updatedBy:
        adminUid,

      message:
        "Order shipped successfully.",
    };
  }
);


// ============================================================
// CANCEL ORDER - ADMIN ONLY
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
      cleanString(data.orderId);

    const reason =
      cleanString(data.reason);

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
          { merge: true }
        );
      }
    );

    return {
      success: true,
      orderId,

      status:
        "Cancelled",

      cancelledBy:
        adminUid,

      message:
        "Order cancelled successfully.",
    };
  }
);


// ============================================================
// ASSIGN ORDER TO COURIER - ADMIN ONLY
//
// SECURITY:
//
// Target courier MUST:
//
// users/{uid}
// couriers/{uid}
//
// role = courier
// status = approved
// active = true
// approvedByAdmin = true
//
// Order MUST:
//
// status = Shipped
//
// Courier information is NEVER trusted from client.
// It is read from Firestore.
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
      cleanString(data.orderId);

    const courierId =
      cleanString(data.courierId);

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

    // --------------------------------------------------------
    // NEVER TRUST COURIER NAME / PHONE FROM CLIENT
    // --------------------------------------------------------

    const courier =
      await verifyTargetCourier(
        courierId
      );

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

        if (currentStatus !== "Shipped") {
          throw new HttpsError(
            "failed-precondition",
            "Courier can only be assigned to a Shipped order."
          );
        }

        const existingCourierId =
          cleanString(
            orderData.courierId
          );

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
              courier.name,

            courierPhone:
              courier.phone,

            courierAssignedAt:
              FieldValue.serverTimestamp(),

            courierAssignedBy:
              adminUid,

            updatedAt:
              FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
      }
    );

    return {
      success: true,

      orderId,

      courierId,

      courierPersonName:
        courier.name,

      courierPhone:
        courier.phone,

      assignedBy:
        adminUid,

      message:
        "Approved and active courier assigned successfully.",
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
//
// IMPORTANT:
//
// Courier can ONLY change delivery-status fields.
// Payment/COD/order-total fields are NEVER accepted
// from courier request.
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
      cleanString(data.orderId);

    const requestedStatus =
      cleanString(data.status);

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

    const allowedCourierStatuses = [
      "Picked by Courier",
      "Out for Delivery",
      "Delivered",
    ];

    if (
      !allowedCourierStatuses.includes(
        newStatus
      )
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

        // ----------------------------------------------------
        // VERIFY ASSIGNMENT
        // ----------------------------------------------------

        const assignedCourierId =
          cleanString(
            orderData.courierId
          );

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

        // ----------------------------------------------------
        // VERIFY CURRENT STATUS
        // ----------------------------------------------------

        const currentStatus =
          normalizeOrderStatus(
            orderData.orderStatus ||
            orderData.status
          );

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

        // ----------------------------------------------------
        // IMPORTANT COD / PAYMENT PROTECTION
        //
        // We intentionally construct updateData ONLY with
        // courier delivery fields.
        //
        // Client cannot pass paymentMethod,
        // paymentStatus, codAmount, totalAmount,
        // subtotal, discount, deliveryFee, etc.
        // ----------------------------------------------------

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
          { merge: true }
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
