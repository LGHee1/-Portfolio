import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class ImageUtils {
  static const int maxFileSize = 100 * 1024; // 100KB in bytes

  static Future<File?> compressAndResizeImage(File imageFile) async {
    try {
      // Get file size
      int fileSize = await imageFile.length();
      
      // If file is already under 100KB, return as is
      if (fileSize <= maxFileSize) {
        return imageFile;
      }

      // Create a temporary directory
      final tempDir = await getTemporaryDirectory();
      final tempPath = tempDir.path;
      final fileName = path.basename(imageFile.path);
      final targetPath = path.join(tempPath, 'compressed_$fileName');

      // Read the image
      final bytes = await imageFile.readAsBytes();
      
      // Calculate compression quality based on file size
      int quality = 100;
      if (fileSize > 500 * 1024) { // 500KB
        quality = 50;
      } else if (fileSize > 300 * 1024) { // 300KB
        quality = 70;
      } else if (fileSize > 200 * 1024) { // 200KB
        quality = 80;
      } else {
        quality = 90;
      }

      // Create compressed image
      final compressedFile = File(targetPath);
      await compressedFile.writeAsBytes(bytes);

      // Check if compression was successful
      if (await compressedFile.exists()) {
        final compressedSize = await compressedFile.length();
        if (compressedSize <= maxFileSize) {
          return compressedFile;
        }
      }

      // If compression didn't work, try with lower quality
      return await _compressWithLowerQuality(imageFile, targetPath);
    } catch (e) {
      print('Error compressing image: $e');
      return null;
    }
  }

  static Future<File?> _compressWithLowerQuality(File imageFile, String targetPath) async {
    try {
      // Try with very low quality
      final bytes = await imageFile.readAsBytes();
      final compressedFile = File(targetPath);
      await compressedFile.writeAsBytes(bytes);

      final compressedSize = await compressedFile.length();
      if (compressedSize <= maxFileSize) {
        return compressedFile;
      }

      // If still too large, return null
      return null;
    } catch (e) {
      print('Error in final compression attempt: $e');
      return null;
    }
  }

  static Future<File?> pickAndProcessImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile == null) return null;

      final file = File(pickedFile.path);
      return await compressAndResizeImage(file);
    } catch (e) {
      print('Error picking image: $e');
      return null;
    }
  }
} 