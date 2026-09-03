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
    // Check login
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "You must be logged in."
      );
    }

    const adminUid = request.auth.uid;

    // Check Admin document
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

    // Request data
    const data = request.data || {};

    const name = String(data.name || "").trim();
    const email = String(data.email || "")
        .trim()
        .toLowerCase();
    const phone = String(data.phone || "").trim();
    const password = String(data.password || "");

    // Validation
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

    // Check existing Firebase user
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

    // Create Firebase Auth user
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

    // Create Firestore records
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

      // Roll back Firebase Auth user
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
    // --------------------------------------------------------
    // 1. Check Admin Login
    // --------------------------------------------------------

    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "You must be logged in."
      );
    }

    const adminUid = request.auth.uid;

    // --------------------------------------------------------
    // 2. Verify Admin
    // --------------------------------------------------------

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

    // --------------------------------------------------------
    // 3. Get Request Data
    // --------------------------------------------------------

    const data = request.data || {};

    const targetUid = String(
      data.uid || ""
    ).trim();

    const targetEmail = String(
      data.email || ""
    ).trim()
        .toLowerCase();

    // UID preferred
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

    // --------------------------------------------------------
    // 4. Get Existing User Data
    // --------------------------------------------------------

    const userRef = db
        .collection("users")
        .doc(vendorUid);

    const userDoc = await userRef.get();

    const existingUserData = userDoc.exists
      ? userDoc.data() || {}
      : {};

    // --------------------------------------------------------
    // 5. Prevent Admin/Courier From Becoming Vendor
    // --------------------------------------------------------

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

    // --------------------------------------------------------
    // 6. Vendor Basic Details
    // --------------------------------------------------------

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
      ).trim()
        .toLowerCase();

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

    // --------------------------------------------------------
    // 7. Create / Update User + Vendor Records
    // --------------------------------------------------------

    try {
      const batch = db.batch();

      // users/{uid}
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

      // vendors/{uid}
      const vendorRef = db
          .collection("vendors")
          .doc(vendorUid);

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

          ...(await vendorRef.get()).exists
            ? {}
            : {
                createdAt:
                  FieldValue.serverTimestamp(),
              },
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

    // --------------------------------------------------------
    // 8. Success Response
    // --------------------------------------------------------

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
