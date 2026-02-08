/// Application configuration
/// 
/// To change the API base URL, modify the values below:
/// - For Android Emulator: Use 'http://10.0.2.2:8000/api/v1'
/// - For iOS Simulator: Use 'http://127.0.0.1:8000/api/v1' or 'http://localhost:8000/api/v1'
/// - For Physical Devices: Use your computer's local IP (e.g., 'http://192.168.1.XXX:8000/api/v1')
/// 
/// To find your local IP:
/// - macOS/Linux: Run `ifconfig` or `ip addr` and look for your local network IP
/// - Windows: Run `ipconfig` and look for IPv4 Address
class AppConfig {
  // Base API URL - Update this with your server's IP address
  // For development, you can use environment variables or const values
  static const String _defaultBaseUrl = 'http://10.0.2.2:8000/api/v1';
  static const String _iosBaseUrl = 'http://127.0.0.1:8000/api/v1';
  static const String _productionBaseUrl = 'https://backend-barber-zb9j.onrender.com/api/v1';
  
  // Set to false to use local development server
  static const bool useProduction = false;
  
  /// Get the base URL based on the platform
  static String getBaseUrl() {
    if (useProduction) {
      return _productionBaseUrl;
    }
    
    // For local Android emulator (use 10.0.2.2) or Physical Device (use Mac IP)
    return 'http://192.168.0.122:8000/api/v1';
  }
  
  /// Get iOS-specific base URL
  /// For physical devices, replace with your computer's IP: 'http://YOUR_IP:8000/api/v1'
  static String getIosBaseUrl() {
    if (useProduction) {
      return _productionBaseUrl;
    }
    // Use Mac's local IP for all devices (Simulator & Physical)
    return 'http://192.168.0.122:8000/api/v1';
  }
  
  /// Connection timeout in seconds
  static const int connectTimeoutSeconds = 10;
  
  /// Receive timeout in seconds  
  static const int receiveTimeoutSeconds = 10;
}
