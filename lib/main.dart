import 'package:aiviser/screens/home_screen.dart';
import 'package:aiviser/screens/map_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/sign_in_screen.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'widgets/no_connection_modal.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: WidgetsFlutterBinding.ensureInitialized());
  await Firebase.initializeApp();
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final Connectivity _connectivity = Connectivity();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
    _initializeApp();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _reloadUser();
    }
  }

  Future<void> _reloadUser() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await user.reload();
    }
  }

  Future<void> _initializeApp() async {
    FlutterNativeSplash.remove();
  }

  void _updateConnectionStatus(ConnectivityResult result) {
    if (result == ConnectivityResult.none) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return NoConnectionModal(
            onRetry: () async {
              Navigator.of(context).pop();
              final connectivityResult = await _connectivity.checkConnectivity();
              _updateConnectionStatus(connectivityResult);
            },
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Localizations(
      locale: const Locale('en', ''),
      delegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      child: MaterialApp(
        title: 'Nearby Places',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          brightness: Brightness.light,
          scaffoldBackgroundColor: Colors.white,
          colorScheme: const ColorScheme.light(
            primary: Colors.teal,
            secondary: Colors.teal,
            surface: Colors.white,
          ),
          bottomAppBarTheme: const BottomAppBarTheme(
            color: Colors.black,
          ),
        ),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('en', ''), // English
        ],
        home: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, AsyncSnapshot<User?> snapshot) {
            if (snapshot.connectionState == ConnectionState.active) {
              final User? user = snapshot.data;
              if (user == null) {
                return const SignInScreen();
              }
              return const HomeScreen();
            }
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          },
        ),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
