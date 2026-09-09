import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:stok_anandam/core/auth/current_user_store.dart';
import 'package:stok_anandam/core/routing/app_router.dart';
import 'package:stok_anandam/core/services/heartbeat_service.dart';
import 'package:stok_anandam/core/theme/app_theme.dart';
import 'injection.dart';
import 'features/auth/bloc/auth_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env', isOptional: true);
  await setupLocator();
  HeartbeatService.instance.start();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        BlocProvider(create: (_) => AuthBloc()),
        ChangeNotifierProvider.value(value: getIt<CurrentUserStore>()),
      ],
      child: MaterialApp.router(
        title: 'Movva by Anandam.id',
        theme: AppTheme.light.copyWith(
          textTheme: GoogleFonts.interTextTheme(AppTheme.light.textTheme),
        ),
        darkTheme: AppTheme.dark.copyWith(
          textTheme: GoogleFonts.interTextTheme(AppTheme.dark.textTheme),
        ),
        themeMode: ThemeMode.light,
        routerConfig: appRouter,
        scaffoldMessengerKey: messengerKey,
      ),
    );
  }
}
