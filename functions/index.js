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
