import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/role_theme.dart';
import 'core/widgets/app_toast.dart';
import 'features/customer/cart/cart_provider.dart';
import 'routes/app_routes.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WaterBusinessApp());
}

class WaterBusinessApp extends StatelessWidget {
  const WaterBusinessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => RoleThemeProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => CartProvider(),
        ),
      ],
      child: Consumer<RoleThemeProvider>(
        builder: (context, roleThemeProvider, _) {
          return MaterialApp(
            title: AppConstants.appName,
            scaffoldMessengerKey: rootScaffoldMessengerKey,
            debugShowCheckedModeBanner: false,
            theme: roleThemeProvider.currentThemeData,
            initialRoute: AppRoutes.splash,
            onGenerateRoute: AppRoutes.generateRoute,
          );
        },
      ),
    );
  }
}