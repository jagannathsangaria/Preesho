const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { initializeApp } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const {
  getFirestore,
  FieldValue,
} = require("firebase-admin/firestore");

initializeApp();

const db = getFirestore();
const auth = getAuth();


// ============================================================
// CREATE COURIER ACCOUNT
// ============================================================

exports.createCourierAccount = onCall(
  {
    region: "asia-south1",
  },
  async (request) => {
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
        "Only Admin can create courier accounts."
      );
    }

    const adminData = adminDoc.data() || {};

    const adminRole = String(
      adminData.Role || adminData.role || ""
    ).toLowerCase();

    if (adminRole !== "admin") {
      throw new HttpsError(
        "permission-denied",
        "Admin permission required."
      );
    }

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
      if (error.code !== "auth/user-not-found") {
        if (error instanceof HttpsError) {
          throw error;
        }

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
          "Rollback failed:",
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
// ============================================================

exports.authorizeVendor = onCall(
  {
    region: "asia-south1",
  },
  async (request) => {
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
        "Only Admin can authorize vendors."
      );
    }

    const adminData = adminDoc.data() || {};

    const adminRole = String(
      adminData.Role || adminData.role || ""
    ).toLowerCase();

    if (adminRole !== "admin") {
      throw new HttpsError(
        "permission-denied",
        "Admin permission required."
      );
    }

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

    const userDoc = await userRef.get();

    const existingUserData = userDoc.exists
      ? userDoc.data() || {}
      : {};

    const existingRole = String(
      existingUserData.role ||
      existingUserData.Role ||
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
        vendorUser.displayName ||
        ""
      ).trim();

    const vendorEmail =
      String(
        data.email ||
        existingUserData.email ||
        vendorUser.email ||
        ""
      ).trim().toLowerCase();

    const vendorPhone =
      String(
        data.phone ||
        existingUserData.phone ||
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

    const vendorRef = db
        .collection("vendors")
        .doc(vendorUid);

    const vendorDoc = await vendorRef.get();

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
          vendorStatus: "approved",
          active: true,
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
          status: "approved",
          active: true,
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
      vendorStatus: "approved",
      active: true,
      message: "Vendor authorized successfully.",
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
        "Only Admin can update vendor status."
      );
    }

    const adminData = adminDoc.data() || {};

    const adminRole = String(
      adminData.Role || adminData.role || ""
    ).toLowerCase();

    if (adminRole !== "admin") {
      throw new HttpsError(
        "permission-denied",
        "Admin permission required."
      );
    }

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

    const batch = db.batch();

    const isApproved = status === "approved";

    batch.set(
      userRef,
      {
        role: "vendor",
        vendorStatus: status,
        active: isApproved,
        vendorStatusUpdatedAt:
          FieldValue.serverTimestamp(),
        vendorStatusUpdatedBy: adminUid,
        vendorStatusReason: reason,
        updatedAt:
          FieldValue.serverTimestamp(),
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
        statusUpdatedBy: adminUid,
        statusReason: reason,
        updatedAt:
          FieldValue.serverTimestamp(),
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
      message: "Vendor status updated successfully.",
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
        "Only Admin can verify vendor documents."
      );
    }

    const adminData = adminDoc.data() || {};

    const adminRole = String(
      adminData.Role || adminData.role || ""
    ).toLowerCase();

    if (adminRole !== "admin") {
      throw new HttpsError(
        "permission-denied",
        "Admin permission required."
      );
    }

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

    const vendorDoc = await vendorRef.get();

    if (!vendorDoc.exists) {
      throw new HttpsError(
        "not-found",
        "Vendor not found."
      );
    }

    const vendorData = vendorDoc.data() || {};

    const existingDocuments =
      vendorData.documents || {};

    const existingDocument =
      existingDocuments[documentType] || {};

    const updatedDocument = {
      ...existingDocument,

      status: status,

      verificationReason: reason,

      verifiedBy: adminUid,

      verifiedAt:
        FieldValue.serverTimestamp(),

      updatedAt:
        FieldValue.serverTimestamp(),
    };

    await vendorRef.set(
      {
        documents: {
          [documentType]: updatedDocument,
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
