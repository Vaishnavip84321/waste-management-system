const bcrypt = require("bcrypt");
const jwt = require("jsonwebtoken");
const pool = require("../config/db");

// REGISTER
const register = async (req, res) => {
  try {
    const { full_name, email, phone, password, role } = req.body;

    // Check required fields
    if (!full_name || !phone || !password || !role) {
      return res.status(400).json({
        success: false,
        message: "Full name, phone, password and role are required",
      });
    }

    // Check valid role
    const allowedRoles = ["CITIZEN", "DRIVER", "ADMIN"];

    if (!allowedRoles.includes(role)) {
      return res.status(400).json({
        success: false,
        message: "Invalid role",
      });
    }

    // Check whether phone already exists
    const existingUser = await pool.query(
      "SELECT user_id FROM users WHERE phone = $1",
      [phone]
    );

    if (existingUser.rows.length > 0) {
      return res.status(409).json({
        success: false,
        message: "Phone number already registered",
      });
    }

    // Check email if provided
    if (email) {
      const existingEmail = await pool.query(
        "SELECT user_id FROM users WHERE email = $1",
        [email]
      );

      if (existingEmail.rows.length > 0) {
        return res.status(409).json({
          success: false,
          message: "Email already registered",
        });
      }
    }

    // Hash password
    const passwordHash = await bcrypt.hash(password, 10);

    // Create user
    const result = await pool.query(
      `INSERT INTO users
        (full_name, email, phone, password_hash, role)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING user_id, full_name, email, phone, role, is_active, created_at`,
      [full_name, email || null, phone, passwordHash, role]
    );

    res.status(201).json({
      success: true,
      message: "User registered successfully",
      user: result.rows[0],
    });
  } catch (error) {
    console.error("Registration error:", error.message);

    res.status(500).json({
      success: false,
      message: "Registration failed",
    });
  }
};

// LOGIN
const login = async (req, res) => {
  try {
    const { phone, password } = req.body;

    if (!phone || !password) {
      return res.status(400).json({
        success: false,
        message: "Phone and password are required",
      });
    }

    // Find user
    const result = await pool.query(
      `SELECT user_id, full_name, email, phone,
              password_hash, role, is_active
       FROM users
       WHERE phone = $1`,
      [phone]
    );

    if (result.rows.length === 0) {
      return res.status(401).json({
        success: false,
        message: "Invalid phone or password",
      });
    }

    const user = result.rows[0];

    // Check account status
    if (!user.is_active) {
      return res.status(403).json({
        success: false,
        message: "Account is inactive",
      });
    }

    // Verify password
    const passwordMatch = await bcrypt.compare(
      password,
      user.password_hash
    );

    if (!passwordMatch) {
      return res.status(401).json({
        success: false,
        message: "Invalid phone or password",
      });
    }

    // Create JWT
    const token = jwt.sign(
      {
        user_id: user.user_id,
        role: user.role,
      },
      process.env.JWT_SECRET,
      {
        expiresIn: "1d",
      }
    );

    // Never send password hash to frontend
    delete user.password_hash;

    res.json({
      success: true,
      message: "Login successful",
      token,
      user,
    });
  } catch (error) {
    console.error("Login error:", error.message);

    res.status(500).json({
      success: false,
      message: "Login failed",
    });
  }
};

module.exports = {
  register,
  login,
};