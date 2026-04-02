import 'package:flutter/material.dart';
import '../../models/user_role_model.dart';
import '../login_screen.dart';

class LoginDosenScreen extends StatelessWidget {
  const LoginDosenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LoginScreen(userRole: UserRole.dosen);
  }
}
