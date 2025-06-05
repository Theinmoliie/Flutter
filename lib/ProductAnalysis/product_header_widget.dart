// product_header_widget.dart
import 'dart:io'; // For File type if you use local image files
import 'package:flutter/material.dart';

class ProductHeaderWidget extends StatelessWidget {
  final String productName;
  final String brand;
  final String? imageUrl; // For network images
  final File? imageFile;  // For local image files (e.g., from camera/gallery)

  const ProductHeaderWidget({
    Key? key,
    required this.productName,
    required this.brand,
    this.imageUrl,
    this.imageFile,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Determine if a valid image source is available
    bool hasNetworkImage = imageUrl != null && imageUrl!.isNotEmpty;
    bool hasFileImage = imageFile != null;
    bool hasDisplayableImage = hasNetworkImage || hasFileImage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Product Name
        Text(
          productName,
          style: const TextStyle(
            fontSize: 22, // Or Theme.of(context).textTheme.headlineSmall?.fontSize
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),

        // Brand Name
        Text(
          brand,
          style: TextStyle(
            fontSize: 16, // Or Theme.of(context).textTheme.titleMedium?.fontSize
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),

        // Product Image
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container( // Added a container for placeholder background and consistent sizing
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey[200], // Placeholder background color
              borderRadius: BorderRadius.circular(12),
            ),
            child: hasDisplayableImage
                ? (hasNetworkImage
                    ? Image.network(
                        imageUrl!,
                        fit: BoxFit.cover,
                        width: 200,
                        height: 200,
                        loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                  : null,
                              strokeWidth: 2.0,
                            ),
                          );
                        },
                        errorBuilder: (BuildContext context, Object exception, StackTrace? stackTrace) {
                          print("Error loading network image: $exception");
                          return Image.asset(
                            'assets/placeholder.png', // Ensure this asset exists in your project
                            fit: BoxFit.cover,
                            width: 200,
                            height: 200,
                          );
                        },
                      )
                    : Image.file( // This implies imageFile is not null
                        imageFile!,
                        fit: BoxFit.cover,
                        width: 200,
                        height: 200,
                        errorBuilder: (BuildContext context, Object exception, StackTrace? stackTrace) {
                           print("Error loading file image: $exception");
                           return Image.asset(
                            'assets/placeholder.png', // Ensure this asset exists
                            fit: BoxFit.cover,
                            width: 200,
                            height: 200,
                          );
                        },
                      ))
                : Image.asset( // Fallback if no image source is provided
                    'assets/placeholder.png', // Ensure this asset exists
                    fit: BoxFit.cover,
                    width: 200,
                    height: 200,
                  ),
          ),
        ),
      ],
    );
  }
}