import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'login_page.dart';
import 'admin_login.dart';
import 'orders_page.dart';
import 'cart/cart_controller.dart';
import 'cart/cart_page.dart';

class ProfilePage extends StatefulWidget {
  final VoidCallback? onCartChanged;

  const ProfilePage({
    super.key,
    this.onCartChanged,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  User? get user => FirebaseAuth.instance.currentUser;

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('You have been logged out successfully'),
      ),
    );
  }

  void _openLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LoginPage(),
      ),
    ).then((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _openCart() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CartPage(
          onCartChanged: () {
            widget.onCartChanged?.call();

            if (mounted) {
              setState(() {});
            }
          },
        ),
      ),
    ).then((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _showComingSoon(String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$title coming soon'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = user;
    final cartCount = CartController.itemCount;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'My Profile',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                onPressed: _openCart,
                icon: const Icon(
                  Icons.shopping_bag_outlined,
                  size: 26,
                ),
              ),
              if (cartCount > 0)
                Positioned(
                  right: 2,
                  top: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE53935),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFF7F7FA),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      cartCount > 99 ? '99+' : '$cartCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {});
          await Future<void>.delayed(
            const Duration(milliseconds: 300),
          );
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            20,
            8,
            20,
            35,
          ),
          children: [
            _ProfileHeader(
              user: currentUser,
              onLogin: _openLogin,
            ),

            const SizedBox(height: 20),

            if (currentUser == null)
              _LoginCard(
                onLogin: _openLogin,
              ),

            if (currentUser != null) ...[
              _SectionTitle(
                title: 'My Account',
              ),
              const SizedBox(height: 10),

              _ProfileMenuTile(
                icon: Icons.receipt_long_rounded,
                title: 'My Orders',
                subtitle:
                    'Track and manage your orders',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const OrdersPage(),
                    ),
                  );
                },
              ),

              _ProfileMenuTile(
                icon: Icons.location_on_outlined,
                title: 'Saved Addresses',
                subtitle:
                    'Manage your delivery addresses',
                onTap: () {
                  _showComingSoon('Saved Addresses');
                },
              ),

              const SizedBox(height: 16),

              _SectionTitle(
                title: 'Preesho Services',
              ),
              const SizedBox(height: 10),

              _ProfileMenuTile(
                icon: Icons.admin_panel_settings_outlined,
                title: 'Admin Login',
                subtitle:
                    'Access Preesho admin panel',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AdminLogin(),
                    ),
                  );
                },
              ),
            ],

            if (currentUser == null) ...[
              _SectionTitle(
                title: 'Explore',
              ),
              const SizedBox(height: 10),

              _ProfileMenuTile(
                icon: Icons.receipt_long_rounded,
                title: 'My Orders',
                subtitle:
                    'Login to view your orders',
                onTap: _openLogin,
              ),

              _ProfileMenuTile(
                icon: Icons.location_on_outlined,
                title: 'Saved Addresses',
                subtitle:
                    'Login to manage your addresses',
                onTap: _openLogin,
              ),
            ],

            const SizedBox(height: 16),

            _SectionTitle(
              title: 'Help & Support',
            ),
            const SizedBox(height: 10),

            _ProfileMenuTile(
              icon: Icons.support_agent_rounded,
              title: 'Help & Support',
              subtitle:
                  'Get help with your Preesho experience',
              onTap: () {
                _showComingSoon('Help & Support');
              },
            ),

            _ProfileMenuTile(
              icon: Icons.info_outline_rounded,
              title: 'About Preesho',
              subtitle:
                  'Learn more about Preesho',
              onTap: () {
                showAboutDialog(
                  context: context,
                  applicationName: 'Preesho',
                  applicationVersion: '1.0.0',
                  applicationIcon: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0EBFF),
                      borderRadius:
                          BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.shopping_bag_rounded,
                      color: Color(0xFF5B35D5),
                    ),
                  ),
                  children: const [
                    Text(
                      'Preesho is a modern shopping experience '
                      'for discovering and ordering products.',
                    ),
                  ],
                );
              },
            ),

            if (currentUser != null) ...[
              const SizedBox(height: 18),

              _LogoutButton(
                onPressed: _logout,
              ),
            ],

            const SizedBox(height: 24),

            Center(
              child: Column(
                children: [
                  Text(
                    'Preesho',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Shop smart. Live better.',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// PROFILE HEADER
// ============================================================

class _ProfileHeader extends StatelessWidget {
  final User? user;
  final VoidCallback onLogin;

  const _ProfileHeader({
    required this.user,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    final loggedIn = user != null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF6C45E8),
            Color(0xFF4324B5),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5B35D5).withOpacity(0.25),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.35),
                width: 1.5,
              ),
            ),
            child: const Icon(
              Icons.person_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  loggedIn
                      ? 'Welcome back!'
                      : 'Welcome to Preesho',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  loggedIn
                      ? (user?.email ?? 'Preesho Customer')
                      : 'Login to access your account',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (!loggedIn)
            IconButton(
              onPressed: onLogin,
              style: IconButton.styleFrom(
                backgroundColor:
                    Colors.white.withOpacity(0.16),
              ),
              icon: const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================
// LOGIN CARD
// ============================================================

class _LoginCard extends StatelessWidget {
  final VoidCallback onLogin;

  const _LoginCard({
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.045),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF0EBFF),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.lock_open_rounded,
              color: Color(0xFF5B35D5),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Login for a better experience',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'View orders, addresses and more',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: onLogin,
            child: const Text(
              'Login',
              style: TextStyle(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// SECTION TITLE
// ============================================================

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.2,
      ),
    );
  }
}

// ============================================================
// PROFILE MENU TILE
// ============================================================

class _ProfileMenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ProfileMenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 15,
              vertical: 12,
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0EBFF),
                    borderRadius:
                        BorderRadius.circular(15),
                  ),
                  child: Icon(
                    icon,
                    color: const Color(0xFF5B35D5),
                    size: 23,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.grey.shade500,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// LOGOUT BUTTON
// ============================================================

class _LogoutButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _LogoutButton({
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(
          Icons.logout_rounded,
          color: Color(0xFFE53935),
        ),
        label: const Text(
          'Logout',
          style: TextStyle(
            color: Color(0xFFE53935),
            fontWeight: FontWeight.w800,
          ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          side: BorderSide(
            color: Colors.red.shade100,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
          ),
        ),
      ),
    );
  }
}
