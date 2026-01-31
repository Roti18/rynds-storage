import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

class ApiConfig {
  static String get _cleanBaseUrl {
    // Priority: dotenv (runtime .env file) -> String.fromEnvironment (build-time arg) -> Default
    String? envUrl;
    try {
      if (dotenv.isInitialized) {
        envUrl = dotenv.env['BASE_URL'];
      }
    } catch (_) {}

    String url = envUrl ?? 
                 const String.fromEnvironment('BASE_URL', defaultValue: 'https://storage.rynds.my.id');
    
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  static String get baseUrl => _cleanBaseUrl;

  static String get appName {
     String? envName;
     try {
       if (dotenv.isInitialized) {
         envName = dotenv.env['NAME_APP'];
       }
     } catch (_) {}

     return envName ?? 
            const String.fromEnvironment('NAME_APP', defaultValue: 'RYNDS STORAGE');
  }

  // Endpoints
  static String get login => '$baseUrl/api/login';
  static String get files => '$baseUrl/api/files';
  static String get preview => '$baseUrl/api/preview';
  static String get download => '$baseUrl/api/download';
  static String get folder => '$baseUrl/api/folder';
  static String get upload => '$baseUrl/api/upload';
  static String get rename => '$baseUrl/api/rename';
  static String get copy => '$baseUrl/api/copy';
  static String get duplicate => '$baseUrl/api/duplicate';
  static String get delete => '$baseUrl/api/delete';
  static String get storages => '$baseUrl/api';
  static String get stats => '$baseUrl/api/stats';
  static String get search => '$baseUrl/api/search';
  static String get recent => '$baseUrl/api/recent';
  static String get reindex => '$baseUrl/api/reindex';
  static String get ping => '$baseUrl/ping';
}
