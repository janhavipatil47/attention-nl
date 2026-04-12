import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'screens/homePage.dart';
import 'screens/login.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NeuroLearn',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const _AppStartGate(),
    );
  }
}

class _AppStartGate extends StatelessWidget {
  const _AppStartGate();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AuthUser?>(
      future: AuthService.currentUser(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return const NeuroLearnLogin();
        }

        return LearningHomeScreen(userId: user.id, userName: user.fullName);
      },
    );
  }
}

