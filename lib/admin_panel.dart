import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';

class AdminPanel extends StatefulWidget {
const AdminPanel({super.key});

@override
State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {
final _formKey = GlobalKey<FormState>();

// ============================================================
// PRODUCT CONTROLLERS
// ============================================================

final nameController = TextEditingController();
final categoryController = TextEditingController();
final priceController = TextEditingController();
final stockController = TextEditingController();

// Multiple image URLs.
// Admin can enter one URL per line OR separate URLs with comma.
final imageUrlsController = TextEditingController();

final descriptionController = TextEditingController();
final remarkController = TextEditingController();

// Additional product details
final brandController = TextEditingController();
final materialController = TextEditingController();
final colorController = TextEditingController();
final sizeController = TextEditingController();
final weightController = TextEditingController();
final warrantyController = TextEditingController();
final highlightsController = TextEditingController();

bool active = true;
bool saving = false;
bool uploadingExcel = false;
bool downloadingTemplate = false;

final productsRef =
FirebaseFirestore.instance.collection('products');

final ordersRef =
FirebaseFirestore.instance.collection('orders');

static const List<String> orderStatuses = [
'Placed',
'Confirmed',
'Packed',
'Shipped',
'Delivered',
'Cancelled',
];

// ============================================================
// DISPOSE
// ============================================================

@override
void dispose() {
nameController.dispose();
categoryController.dispose();
priceController.dispose();
stockController.dispose();
imageUrlsController.dispose();
descriptionController.dispose();
remarkController.dispose();

brandController.dispose();  
materialController.dispose();  
colorController.dispose();  
sizeController.dispose();  
weightController.dispose();  
warrantyController.dispose();  
highlightsController.dispose();  

super.dispose();

}

// ============================================================
// MULTIPLE IMAGE URL PARSER
// ============================================================

List<String> parseImageUrls(String text) {
return text
.split(RegExp(r'[\n,]+'))
.map((url) => url.trim())
.where((url) => url.isNotEmpty)
.toList();
}

// ============================================================
// SAVE SINGLE PRODUCT
// ============================================================

Future<void> saveProduct() async {
if (!_formKey.currentState!.validate()) {
return;
}

setState(() {  
  saving = true;  
});  

try {  
  final stock =  
      int.tryParse(stockController.text.trim()) ?? 0;  

  final price =  
      double.tryParse(priceController.text.trim());  

  if (price == null) {  
    throw Exception('Please enter a valid price.');  
  }  

  final imageUrls =  
      parseImageUrls(imageUrlsController.text);  

  if (imageUrls.isEmpty) {  
    throw Exception(  
      'Please enter at least one valid image URL.',  
    );  
  }  

  await productsRef.add({  
    'Name': nameController.text.trim(),  
    'Category': categoryController.text.trim(),  
    'Price': price,  
    'Stock': stock < 0 ? 0 : stock,  

    // New multiple image field  
    'ImageUrls': imageUrls,  

    // Keep old field for compatibility  
    'Imageurl': imageUrls.first,  

    'Description':  
        descriptionController.text.trim(),  

    'Remark':  
        remarkController.text.trim(),  

    // Additional product details  
    'Brand':  
        brandController.text.trim(),  

    'Material':  
        materialController.text.trim(),  

    'Color':  
        colorController.text.trim(),  

    'Size':  
        sizeController.text.trim(),  

    'Weight':  
        weightController.text.trim(),  

    'Warranty':  
        warrantyController.text.trim(),  

    'Highlights':  
        highlightsController.text.trim(),  

    'Active': active,  

    'CreatedAt':  
        FieldValue.serverTimestamp(),  
  });  

  if (!mounted) return;  

  clearForm();  

  ScaffoldMessenger.of(context).showSnackBar(  
    const SnackBar(  
      content: Text(  
        'Product added successfully',  
      ),  
    ),  
  );  
} on FirebaseException catch (e) {  
  if (!mounted) return;  

  ScaffoldMessenger.of(context).showSnackBar(  
    SnackBar(  
      content: Text(  
        'Error adding product:\n'  
        '${e.message ?? e.code}',  
      ),  
    ),  
  );  
} catch (e) {  
  if (!mounted) return;  

  ScaffoldMessenger.of(context).showSnackBar(  
    SnackBar(  
      content: Text(  
        'Error adding product:\n$e',  
      ),  
    ),  
  );  
} finally {  
  if (mounted) {  
    setState(() {  
      saving = false;  
    });  
  }  
}

}

// ============================================================
// DOWNLOAD EXCEL TEMPLATE
// ============================================================

Future<void> downloadExcelTemplate() async {
setState(() {
downloadingTemplate = true;
});

try {  
  final excel = Excel.createExcel();  

  final sheet = excel['Products'];  

  // ========================================================  
  // HEADER ROW  
  // ========================================================  

  sheet.appendRow([  
    TextCellValue('Name'),  
    TextCellValue('Category'),  
    TextCellValue('Price'),  
    TextCellValue('Stock'),  
    TextCellValue('ImageUrls'),  
    TextCellValue('Description'),  
    TextCellValue('Remark'),  
    TextCellValue('Brand'),  
    TextCellValue('Material'),  
    TextCellValue('Color'),  
    TextCellValue('Size'),  
    TextCellValue('Weight'),  
    TextCellValue('Warranty'),  
    TextCellValue('Highlights'),  
    TextCellValue('Active'),  
  ]);  

  // ========================================================  
  // EXAMPLE ROW  
  // ========================================================  

  sheet.appendRow([  
    TextCellValue('Water Bottle'),  
    TextCellValue('Home & Kitchen'),  
    DoubleCellValue(299),  
    IntCellValue(50),  

    TextCellValue(  
      'https://example.com/bottle1.jpg\n'  
      'https://example.com/bottle2.jpg\n'  
      'https://example.com/bottle3.jpg',  
    ),  

    TextCellValue(  
      'Premium stainless steel water bottle',  
    ),  

    TextCellValue(  
      'Limited time offer',  
    ),  

    TextCellValue(  
      'Preesho',  
    ),  

    TextCellValue(  
      'Stainless Steel',  
    ),  

    TextCellValue(  
      'Silver',  
    ),  

    TextCellValue(  
      '1000 ml',  
    ),  

    TextCellValue(  
      '450 g',  
    ),  

    TextCellValue(  
      '1 Year',  
    ),  

    TextCellValue(  
      'Leak Proof, BPA Free, Premium Quality',  
    ),  

    TextCellValue('TRUE'),  
  ]);  

  // ========================================================  
  // SECOND EXAMPLE  
  // ========================================================  

  sheet.appendRow([  
    TextCellValue('Premium Pen'),  
    TextCellValue('Stationery'),  
    DoubleCellValue(99),  
    IntCellValue(100),  

    TextCellValue(  
      'https://example.com/pen1.jpg\n'  
      'https://example.com/pen2.jpg',  
    ),  

    TextCellValue(  
      'Smooth writing premium pen',  
    ),  

    TextCellValue(  
      'Best seller',  
    ),  

    TextCellValue(  
      'Preesho',  
    ),  

    TextCellValue(  
      'Metal',  
    ),  

    TextCellValue(  
      'Black',  
    ),  

    TextCellValue(  
      'Medium',  
    ),  

    TextCellValue(  
      '20 g',  
    ),  

    TextCellValue(  
      '6 Months',  
    ),  

    TextCellValue(  
      'Smooth Writing, Premium Finish',  
    ),  

    TextCellValue('TRUE'),  
  ]);  

  final List<int>? bytes =  
      excel.encode();  

  if (bytes == null) {  
    throw Exception(  
      'Unable to create Excel file',  
    );  
  }  

  await FileSaver.instance.saveFile(  
    name: 'Preesho_Product_Template',  
    bytes: Uint8List.fromList(bytes),  
    fileExtension: 'xlsx',  
    mimeType: MimeType.microsoftExcel,  
  );  

  if (!mounted) return;  

  ScaffoldMessenger.of(context).showSnackBar(  
    const SnackBar(  
      content: Text(  
        'Excel template downloaded successfully',  
      ),  
    ),  
  );  
} catch (e) {  
  if (!mounted) return;  

  ScaffoldMessenger.of(context).showSnackBar(  
    SnackBar(  
      content: Text(  
        'Template download failed:\n$e',  
      ),  
    ),  
  );  
} finally {  
  if (mounted) {  
    setState(() {  
      downloadingTemplate = false;  
    });  
  }  
}

}

// ============================================================
// UPLOAD EXCEL PRODUCTS
// ============================================================

Future<void> uploadExcelProducts() async {
try {
final result =
await FilePicker.platform.pickFiles(
type: FileType.custom,
allowedExtensions: [
'xlsx',
'xls',
],
withData: true,
);

if (result == null ||  
      result.files.isEmpty) {  
    return;  
  }  

  final file = result.files.first;  

  final bytes = file.bytes;  

  if (bytes == null) {  
    throw Exception(  
      'Unable to read selected Excel file.',  
    );  
  }  

  setState(() {  
    uploadingExcel = true;  
  });  

  final excel =  
      Excel.decodeBytes(bytes);  

  if (excel.tables.isEmpty) {  
    throw Exception(  
      'Excel file contains no sheet.',  
    );  
  }  

  final sheetName =  
      excel.tables.keys.first;  

  final sheet =  
      excel.tables[sheetName];  

  if (sheet == null ||  
      sheet.rows.length < 2) {  
    throw Exception(  
      'Excel file has no product data.',  
    );  
  }  

  // ========================================================  
  // READ HEADERS  
  // ========================================================  

  final headers = <String, int>{};  

  for (  
    int i = 0;  
    i < sheet.rows.first.length;  
    i++  
  ) {  
    final cell =  
        sheet.rows.first[i];  

    final value =  
        cell?.value  
                ?.toString()  
                .trim()  
                .toLowerCase() ??  
            '';  

    if (value.isNotEmpty) {  
      headers[value] = i;  
    }  
  }  

  // ========================================================  
  // REQUIRED COLUMNS  
  // ========================================================  

  const requiredHeaders = [  
    'name',  
    'category',  
    'price',  
    'stock',  
  ];  

  for (  
    final header  
    in requiredHeaders  
  ) {  
    if (!headers.containsKey(header)) {  
      throw Exception(  
        'Required column "$header" is missing.\n\n'  
        'Please use the Preesho Excel Template.',  
      );  
    }  
  }  

  // ========================================================  
  // CELL READER  
  // ========================================================  

  String getCell(  
    List<Data?> row,  
    String columnName,  
  ) {  
    final columnIndex =  
        headers[columnName];  

    if (columnIndex == null ||  
        columnIndex >= row.length) {  
      return '';  
    }  

    return row[columnIndex]  
            ?.value  
            ?.toString()  
            .trim() ??  
        '';  
  }  

  int successCount = 0;  
  int skippedCount = 0;  

  WriteBatch batch =  
      FirebaseFirestore.instance.batch();  

  int batchCount = 0;  

  // ========================================================  
  // PROCESS ROWS  
  // ========================================================  

  for (  
    int rowIndex = 1;  
    rowIndex < sheet.rows.length;  
    rowIndex++  
  ) {  
    final row =  
        sheet.rows[rowIndex];  

    final name =  
        getCell(row, 'name');  

    final category =  
        getCell(row, 'category');  

    final priceText =  
        getCell(row, 'price');  

    final stockText =  
        getCell(row, 'stock');  

    final imageUrlsText =  
        getCell(row, 'imageurls');  

    final oldImageUrl =  
        getCell(row, 'imageurl');  

    final description =  
        getCell(row, 'description');  

    final remark =  
        getCell(row, 'remark');  

    final brand =  
        getCell(row, 'brand');  

    final material =  
        getCell(row, 'material');  

    final color =  
        getCell(row, 'color');  

    final size =  
        getCell(row, 'size');  

    final weight =  
        getCell(row, 'weight');  

    final warranty =  
        getCell(row, 'warranty');  

    final highlights =  
        getCell(row, 'highlights');  

    final activeText =  
        getCell(row, 'active');  

    // Empty row  
    if (name.isEmpty &&  
        category.isEmpty &&  
        priceText.isEmpty &&  
        stockText.isEmpty) {  
      continue;  
    }  

    // Required data  
    if (name.isEmpty ||  
        category.isEmpty ||  
        priceText.isEmpty) {  
      skippedCount++;  
      continue;  
    }  

    // Price  
    final numericPrice =  
        double.tryParse(  
      priceText.replaceAll(  
        RegExp(r'[^0-9.]'),  
        '',  
      ),  
    );  

    if (numericPrice == null) {  
      skippedCount++;  
      continue;  
    }  

    // Stock  
    final stock =  
        int.tryParse(stockText) ??  
            0;  

    // ======================================================  
    // IMAGE URLS  
    // ======================================================  

    String imageText =  
        imageUrlsText;  

    if (imageText.isEmpty) {  
      imageText = oldImageUrl;  
    }  

    final imageUrls =  
        parseImageUrls(imageText);  

    // ======================================================  
    // ACTIVE  
    // ======================================================  

    bool isActive = true;  

    if (activeText.isNotEmpty) {  
      final normalized =  
          activeText  
              .toLowerCase()  
              .trim();  

      isActive =  
          normalized == 'true' ||  
              normalized == 'yes' ||  
              normalized == '1' ||  
              normalized == 'active';  
    }  

    // ======================================================  
    // FIRESTORE DOCUMENT  
    // ========================================================  

    final productDoc =  
        productsRef.doc();  

    batch.set(  
      productDoc,  
      {  
        'Name': name,  
        'Category': category,  
        'Price':  
            numericPrice,  
        'Stock':  
            stock < 0 ? 0 : stock,  

        'ImageUrls':  
            imageUrls,  

        // Compatibility  
        'Imageurl':  
            imageUrls.isNotEmpty  
                ? imageUrls.first  
                : '',  

        'Description':  
            description,  

        'Remark':  
            remark,  

        'Brand':  
            brand,  

        'Material':  
            material,  

        'Color':  
            color,  

        'Size':  
            size,  

        'Weight':  
            weight,  

        'Warranty':  
            warranty,  

        'Highlights':  
            highlights,  

        'Active':  
            isActive,  

        'CreatedAt':  
            FieldValue  
                .serverTimestamp(),  
      },  
    );  

    batchCount++;  
    successCount++;  

    // Firestore batch limit safety  
    if (batchCount >= 450) {  
      await batch.commit();  

      batch =  
          FirebaseFirestore  
              .instance  
              .batch();  

      batchCount = 0;  
    }  
  }  

  if (batchCount > 0) {  
    await batch.commit();  
  }  

  if (!mounted) return;  

  await showDialog(  
    context: context,  
    builder: (context) {  
      return AlertDialog(  
        title: const Row(  
          children: [  
            Icon(  
              Icons.upload_file,  
              color: Colors.green,  
            ),  
            SizedBox(width: 10),  
            Text(  
              'Upload Complete',  
            ),  
          ],  
        ),  
        content: Column(  
          mainAxisSize:  
              MainAxisSize.min,  
          crossAxisAlignment:  
              CrossAxisAlignment.start,  
          children: [  
            Text(  
              'Successfully Added: '  
              '$successCount products',  
              style:  
                  const TextStyle(  
                fontWeight:  
                    FontWeight.bold,  
                color:  
                    Colors.green,  
              ),  
            ),  
            const SizedBox(  
              height: 8,  
            ),  
            Text(  
              'Skipped: '  
              '$skippedCount rows',  
              style: TextStyle(  
                color:  
                    skippedCount > 0  
                        ? Colors.orange  
                        : Colors.grey,  
              ),  
            ),  
            const SizedBox(  
              height: 15,  
            ),  
            const Text(  
              'Products are now '  
              'available in Firestore.',  
            ),  
          ],  
        ),  
        actions: [  
          FilledButton(  
            onPressed: () {  
              Navigator.pop(  
                context,  
              );  
            },  
            child:  
                const Text('OK'),  
          ),  
        ],  
      );  
    },  
  );  
} catch (e) {  
  if (!mounted) return;  

  ScaffoldMessenger.of(context)  
      .showSnackBar(  
    SnackBar(  
      content: Text(  
        'Excel upload failed:\n$e',  
      ),  
      duration:  
          const Duration(  
        seconds: 5,  
      ),  
    ),  
  );  
} finally {  
  if (mounted) {  
    setState(() {  
      uploadingExcel = false;  
    });  
  }  
}

}

// ============================================================
// CLEAR FORM
// ============================================================

void clearForm() {
nameController.clear();
categoryController.clear();
priceController.clear();
stockController.clear();
imageUrlsController.clear();

descriptionController.clear();  
remarkController.clear();  

brandController.clear();  
materialController.clear();  
colorController.clear();  
sizeController.clear();  
weightController.clear();  
warrantyController.clear();  
highlightsController.clear();  

setState(() {  
  active = true;  
});

}

// ============================================================
// DELETE PRODUCT
// ============================================================

Future<void> deleteProduct(
String id,
String name,
) async {
try {
await productsRef
.doc(id)
.delete();

if (!mounted) return;  

  ScaffoldMessenger.of(context)  
      .showSnackBar(  
    SnackBar(  
      content: Text(  
        '"$name" deleted successfully',  
      ),  
    ),  
  );  
} on FirebaseException catch (e) {  
  if (!mounted) return;  

  ScaffoldMessenger.of(context)  
      .showSnackBar(  
    SnackBar(  
      content: Text(  
        'Delete failed:\n'  
        '${e.message ?? e.code}',  
      ),  
    ),  
  );  
}

}

// ============================================================
// UPDATE ORDER STATUS
// ============================================================

Future<void> updateOrderStatus(
String orderId,
String status,
) async {
try {
await ordersRef
.doc(orderId)
.update({
'status': status,
'updatedAt':
FieldValue.serverTimestamp(),
});

if (!mounted) return;  

  ScaffoldMessenger.of(context)  
      .showSnackBar(  
    SnackBar(  
      content: Text(  
        'Order status updated to $status',  
      ),  
    ),  
  );  
} on FirebaseException catch (e) {  
  if (!mounted) return;  

  ScaffoldMessenger.of(context)  
      .showSnackBar(  
    SnackBar(  
      content: Text(  
        'Status update failed:\n'  
        '${e.message ?? e.code}',  
      ),  
    ),  
  );  
}

}

// ============================================================
// INPUT FIELD
// ============================================================

Widget inputField({
required TextEditingController controller,
required String label,
required IconData icon,
TextInputType? keyboardType,
int maxLines = 1,
String? Function(String?)? validator,
String? helperText,
}) {
return Padding(
padding:
const EdgeInsets.only(
bottom: 14,
),
child: TextFormField(
controller: controller,
keyboardType:
keyboardType,
maxLines: maxLines,
validator:
validator,
decoration:
InputDecoration(
labelText: label,
helperText:
helperText,
prefixIcon:
Icon(icon),
border:
OutlineInputBorder(
borderRadius:
BorderRadius.circular(
12,
),
),
),
),
);
}

// ============================================================
// MONEY
// ============================================================

String money(dynamic value) {
if (value is num) {
return '₹${value.toStringAsFixed(0)}';
}

final number =  
    double.tryParse(  
  value?.toString() ?? '',  
);  

if (number == null) {  
  return '₹0';  
}  

return '₹${number.toStringAsFixed(0)}';

}

// ============================================================
// DATE
// ============================================================

String formatDate(
dynamic value,
) {
if (value is! Timestamp) {
return 'Date unavailable';
}

final date =  
    value.toDate();  

final day = date.day  
    .toString()  
    .padLeft(2, '0');  

final month = date.month  
    .toString()  
    .padLeft(2, '0');  

final year =  
    date.year.toString();  

return '$day/$month/$year';

}

// ============================================================
// STATUS COLOR
// ============================================================

Color statusColor(
String status,
) {
switch (
status.toLowerCase()) {
case 'delivered':
return Colors.green;

case 'cancelled':  
    return Colors.red;  

  case 'shipped':  
    return Colors.blue;  

  case 'packed':  
    return Colors.teal;  

  case 'confirmed':  
    return Colors.orange;  

  case 'placed':  
    return Colors.deepPurple;  

  default:  
    return Colors.deepPurple;  
}

}

// ============================================================
// DELETE CONFIRMATION
// ============================================================

Future<void> confirmDelete(
String id,
String name,
) async {
final result =
await showDialog<bool>(
context: context,
builder:
(dialogContext) {
return AlertDialog(
title: const Text(
'Delete Product?',
),
content: Text(
'Are you sure you want '
'to delete "$name"?\n\n'
'This product will also '
'disappear from the '
'customer app.',
),
actions: [
TextButton(
onPressed: () {
Navigator.pop(
dialogContext,
false,
);
},
child:
const Text('Cancel'),
),
FilledButton(
onPressed: () {
Navigator.pop(
dialogContext,
true,
);
},
child:
const Text('Delete'),
),
],
);
},
);

if (result == true) {  
  await deleteProduct(  
    id,  
    name,  
  );  
}

}

// ============================================================
// PRODUCT IMAGE PREVIEW
// ============================================================

Widget productImagePreview(
List<String> imageUrls,
) {
if (imageUrls.isEmpty) {
return Container(
width: 70,
height: 70,
decoration:
BoxDecoration(
borderRadius:
BorderRadius.circular(
10,
),
),
child: const Icon(
Icons
.image_not_supported,
),
);
}

return SizedBox(  
  width: 70,  
  height: 70,  
  child: ClipRRect(  
    borderRadius:  
        BorderRadius.circular(  
      10,  
    ),  
    child: Image.network(  
      imageUrls.first,  
      fit: BoxFit.cover,  
      errorBuilder:  
          (  
        context,  
        error,  
        stack,  
      ) {  
        return const Icon(  
          Icons  
              .image_not_supported,  
        );  
      },  
    ),  
  ),  
);

}

// ============================================================
// BUILD
// ============================================================

@override
Widget build(
BuildContext context,
) {
return Scaffold(
appBar: AppBar(
title: const Text(
'Preesho Admin Panel',
style: TextStyle(
fontWeight:
FontWeight.bold,
),
),
),
body: ListView(
padding:
const EdgeInsets.all(
16,
),
children: [
// ======================================================
// EXCEL BULK UPLOAD
// ======================================================

Container(  
        padding:  
            const EdgeInsets.all(  
          20,  
        ),  
        decoration:  
            BoxDecoration(  
          borderRadius:  
              BorderRadius.circular(  
            18,  
          ),  
          gradient:  
              const LinearGradient(  
            colors: [  
              Color(0xff00695C),  
              Color(0xff26A69A),  
            ],  
          ),  
        ),  
        child: Column(  
          crossAxisAlignment:  
              CrossAxisAlignment  
                  .start,  
          children: [  
            const Row(  
              children: [  
                Icon(  
                  Icons.table_chart,  
                  color:  
                      Colors.white,  
                  size: 30,  
                ),  
                SizedBox(  
                  width: 10,  
                ),  
                Expanded(  
                  child: Text(  
                    'Bulk Product Upload',  
                    style:  
                        TextStyle(  
                      color:  
                          Colors.white,  
                      fontSize: 22,  
                      fontWeight:  
                          FontWeight  
                              .bold,  
                    ),  
                  ),  
                ),  
              ],  
            ),  
            const SizedBox(  
              height: 8,  
            ),  
            const Text(  
              'Add multiple products '  
              'with photos and detailed '  
              'information using Excel.',  
              style: TextStyle(  
                color:  
                    Colors.white70,  
              ),  
            ),  
            const SizedBox(  
              height: 18,  
            ),  
            SizedBox(  
              width:  
                  double.infinity,  
              child:  
                  OutlinedButton  
                      .icon(  
                onPressed:  
                    downloadingTemplate  
                        ? null  
                        : downloadExcelTemplate,  
                style:  
                    OutlinedButton.styleFrom(  
                  foregroundColor:  
                      Colors.white,  
                  side:  
                      const BorderSide(  
                    color:  
                        Colors.white,  
                  ),  
                ),  
                icon:  
                    downloadingTemplate  
                        ? const SizedBox(  
                            width:  
                                20,  
                            height:  
                                20,  
                            child:  
                                CircularProgressIndicator(  
                              color:  
                                  Colors.white,  
                              strokeWidth:  
                                  2,  
                            ),  
                          )  
                        : const Icon(  
                            Icons  
                                .download,  
                          ),  
                label: Text(  
                  downloadingTemplate  
                      ? 'Preparing Template...'  
                      : 'Download Excel Template',  
                ),  
              ),  
            ),  
            const SizedBox(  
              height: 10,  
            ),  
            SizedBox(  
              width:  
                  double.infinity,  
              child:  
                  FilledButton  
                      .icon(  
                onPressed:  
                    uploadingExcel  
                        ? null  
                        : uploadExcelProducts,  
                style:  
                    FilledButton.styleFrom(  
                  backgroundColor:  
                      Colors.white,  
                  foregroundColor:  
                      Colors  
                          .teal  
                          .shade800,  
                ),  
                icon:  
                    uploadingExcel  
                        ? const SizedBox(  
                            width:  
                                20,  
                            height:  
                                20,  
                            child:  
                                CircularProgressIndicator(  
                              strokeWidth:  
                                  2,  
                            ),  
                          )  
                        : const Icon(  
                            Icons  
                                .upload_file,  
                          ),  
                label: Text(  
                  uploadingExcel  
                      ? 'Uploading Products...'  
                      : 'Upload Excel Products',  
                ),  
              ),  
            ),  
          ],  
        ),  
      ),  

      const SizedBox(  
        height: 25,  
      ),  

      // ======================================================  
      // ADD PRODUCT HEADER  
      // ======================================================  

      Container(  
        padding:  
            const EdgeInsets.all(  
          20,  
        ),  
        decoration:  
            BoxDecoration(  
          borderRadius:  
              BorderRadius.circular(  
            18,  
          ),  
          gradient:  
              const LinearGradient(  
            colors: [  
              Color(0xff5E35B1),  
              Color(0xff8E24AA),  
            ],  
          ),  
        ),  
        child: const Column(  
          crossAxisAlignment:  
              CrossAxisAlignment  
                  .start,  
          children: [  
            Text(  
              'Add Single Product',  
              style:  
                  TextStyle(  
                color:  
                    Colors.white,  
                fontSize: 24,  
                fontWeight:  
                    FontWeight.bold,  
              ),  
            ),  
            SizedBox(  
              height: 6,  
            ),  
            Text(  
              'Add product photos '  
              'and complete details.',  
              style:  
                  TextStyle(  
                color:  
                    Colors.white70,  
                fontSize: 14,  
              ),  
            ),  
          ],  
        ),  
      ),  

      const SizedBox(  
        height: 22,  
      ),  

      // ======================================================  
      // PRODUCT FORM  
      // ======================================================  

      Form(  
        key: _formKey,  
        child: Column(  
          children: [  
            inputField(  
              controller:  
                  nameController,  
              label:  
                  'Product Name',  
              icon: Icons  
                  .shopping_bag_outlined,  
              validator:  
                  (value) {  
                if (value ==  
                        null ||  
                    value  
                        .trim()  
                        .isEmpty) {  
                  return 'Enter product name';  
                }  
                return null;  
              },  
            ),  

            inputField(  
              controller:  
                  categoryController,  
              label:  
                  'Category',  
              icon: Icons  
                  .category_outlined,  
              validator:  
                  (value) {  
                if (value ==  
                        null ||  
                    value  
                        .trim()  
                        .isEmpty) {  
                  return 'Enter category';  
                }  
                return null;  
              },  
            ),  

            inputField(  
              controller:  
                  priceController,  
              label:  
                  'Price',  
              icon: Icons  
                  .currency_rupee,  
              keyboardType:  
                  TextInputType  
                      .number,  
              validator:  
                  (value) {  
                if (value ==  
                        null ||  
                    value  
                        .trim()  
                        .isEmpty) {  
                  return 'Enter price';  
                }  

                if (double  
                        .tryParse(  
                      value.trim(),  
                    ) ==  
                    null) {  
                  return 'Enter a valid price';  
                }  

                return null;  
              },  
            ),  

            inputField(  
              controller:  
                  stockController,  
              label:  
                  'Stock',  
              icon: Icons  
                  .inventory_2_outlined,  
              keyboardType:  
                  TextInputType  
                      .number,  
              validator:  
                  (value) {  
                if (value ==  
                        null ||  
                    value  
                        .trim()  
                        .isEmpty) {  
                  return 'Enter stock';  
                }  

                final stock =  
                    int.tryParse(  
                  value.trim(),  
                );  

                if (stock ==  
                        null ||  
                    stock < 0) {  
                  return 'Stock cannot be below 0';  
                }  

                return null;  
              },  
            ),  

            // ==================================================  
            // MULTIPLE IMAGE URLS  
            // ==================================================  

            inputField(  
              controller:  
                  imageUrlsController,  
              label:  
                  'Product Image URLs',  
              icon: Icons  
                  .collections_outlined,  
              keyboardType:  
                  TextInputType.url,  
              maxLines: 5,  
              helperText:  
                  'Enter multiple image URLs. '  
                  'One URL per line or separate with comma.',  
              validator:  
                  (value) {  
                if (value ==  
                        null ||  
                    value  
                        .trim()  
                        .isEmpty) {  
                  return 'Enter at least one image URL';  
                }  

                final urls =  
                    parseImageUrls(  
                  value,  
                );  

                if (urls.isEmpty) {  
                  return 'Enter valid image URL';  
                }  

                for (final url  
                    in urls) {  
                  if (!url  
                      .startsWith(  
                    'http',  
                  )) {  
                    return 'Every image URL must start with http';  
                  }  
                }  

                return null;  
              },  
            ),  

            // ==================================================  
            // DESCRIPTION  
            // ==================================================  

            inputField(  
              controller:  
                  descriptionController,  
              label:  
                  'Product Description',  
              icon: Icons  
                  .description_outlined,  
              maxLines: 5,  
            ),  

            inputField(  
              controller:  
                  remarkController,  
              label:  
                  'Remark / Offer',  
              icon: Icons  
                  .campaign_outlined,  
              maxLines: 2,  
            ),  

            // ==================================================  
            // ADDITIONAL DETAILS  
            // ==================================================  

            const Align(  
              alignment:  
                  Alignment.centerLeft,  
              child: Padding(  
                padding:  
                    EdgeInsets.only(  
                  top: 8,  
                  bottom: 12,  
                ),  
                child: Text(  
                  'Additional Product Details',  
                  style:  
                      TextStyle(  
                    fontSize: 19,  
                    fontWeight:  
                        FontWeight.bold,  
                  ),  
                ),  
              ),  
            ),  

            inputField(  
              controller:  
                  brandController,  
              label:  
                  'Brand',  
              icon: Icons  
                  .verified_outlined,  
            ),  

            inputField(  
              controller:  
                  materialController,  
              label:  
                  'Material',  
              icon: Icons  
                  .texture_outlined,  
            ),  

            inputField(  
              controller:  
                  colorController,  
              label:  
                  'Color',  
              icon: Icons  
                  .palette_outlined,  
            ),  

            inputField(  
              controller:  
                  sizeController,  
              label:  
                  'Size / Capacity',  
              icon: Icons  
                  .straighten_outlined,  
            ),  

            inputField(  
              controller:  
                  weightController,  
              label:  
                  'Weight',  
              icon: Icons  
                  .scale_outlined,  
            ),  

            inputField(  
              controller:  
                  warrantyController,  
              label:  
                  'Warranty',  
              icon: Icons  
                  .security_outlined,  
            ),  

            inputField(  
              controller:  
                  highlightsController,  
              label:  
                  'Product Highlights',  
              icon: Icons  
                  .star_outline,  
              maxLines: 4,  
              helperText:  
                  'Example: Premium quality, '  
                  'Waterproof, Lightweight',  
            ),  

            Card(  
              child:  
                  SwitchListTile(  
                title:  
                    const Text(  
                  'Product Active',  
                ),  
                subtitle:  
                    const Text(  
                  'Active products will appear '  
                  'in customer app.',  
                ),  
                value: active,  
                onChanged:  
                    (value) {  
                  setState(() {  
                    active =  
                        value;  
                  });  
                },  
              ),  
            ),  

            const SizedBox(  
              height: 18,  
            ),  

            SizedBox(  
              width:  
                  double.infinity,  
              height: 52,  
              child:  
                  FilledButton.icon(  
                onPressed:  
                    saving  
                        ? null  
                        : saveProduct,  
                icon:  
                    saving  
                        ? const SizedBox(  
                            width:  
                                20,  
                            height:  
                                20,  
                            child:  
                                CircularProgressIndicator(  
                              strokeWidth:  
                                  2,  
                            ),  
                          )  
                        : const Icon(  
                            Icons  
                                .save_outlined,  
                          ),  
                label: Text(  
                  saving  
                      ? 'Saving...'  
                      : 'Save Product',  
                ),  
              ),  
            ),  

            const SizedBox(  
              height: 12,  
            ),  

            SizedBox(  
              width:  
                  double.infinity,  
              child:  
                  OutlinedButton.icon(  
                onPressed:  
                    saving  
                        ? null  
                        : clearForm,  
                icon:  
                    const Icon(  
                  Icons  
                      .clear_all,  
                ),  
                label:  
                    const Text(  
                  'Clear Form',  
                ),  
              ),  
            ),  
          ],  
        ),  
      ),  

      const SizedBox(  
        height: 30,  
      ),  

      // ======================================================  
      // PRODUCTS  
      // ======================================================  

      const Text(  
        'Products in Firestore',  
        style:  
            TextStyle(  
          fontSize: 21,  
          fontWeight:  
              FontWeight.bold,  
        ),  
      ),  

      const SizedBox(  
        height: 12,  
      ),  

      StreamBuilder<  
          QuerySnapshot<  
              Map<String,  
                  dynamic>>>(  
        stream: productsRef  
            .orderBy(  
              'CreatedAt',  
              descending:  
                  true,  
            )  
            .snapshots(),  
        builder:  
            (context, snapshot) {  
          if (snapshot  
                  .connectionState ==  
              ConnectionState  
                  .waiting) {  
            return const Center(  
              child:  
                  CircularProgressIndicator(),  
            );  
          }  

          if (snapshot  
              .hasError) {  
            return Card(  
              child:  
                  Padding(  
                padding:  
                    const EdgeInsets  
                        .all(  
                  16,  
                ),  
                child: Text(  
                  'Products error:\n'  
                  '${snapshot.error}',  
                ),  
              ),  
            );  
          }  

          final docs =  
              snapshot.data  
                      ?.docs ??  
                  [];  

          if (docs.isEmpty) {  
            return const Card(  
              child:  
                  Padding(  
                padding:  
                    EdgeInsets  
                        .all(  
                  24,  
                ),  
                child:  
                    Center(  
                  child:  
                      Text(  
                    'No products found',  
                  ),  
                ),  
              ),  
            );  
          }  

          return Column(  
            children:  
                docs.map(  
              (doc) {  
                final data =  
                    doc.data();  

                final name =  
                    data['Name']  
                            ?.toString() ??  
                        '';  

                final category =  
                    data['Category']  
                            ?.toString() ??  
                        '';  

                final price =  
                    data['Price'];  

                final stock =  
                    int.tryParse(  
                          data['Stock']  
                                  ?.toString() ??  
                              '0',  
                        ) ??  
                        0;  

                final isActive =  
                    data['Active'] ==  
                        true;  

                List<String>  
                    imageUrls =  
                    [];  

                if (data[  
                        'ImageUrls']  
                    is List) {  
                  imageUrls =  
                      List<String>.from(  
                    (data[  
                                'ImageUrls']  
                            as List)  
                        .map(  
                      (e) =>  
                          e.toString(),  
                    ),  
                  );  
                } else {  
                  final oldImage =  
                      data['Imageurl']  
                              ?.toString() ??  
                          '';  

                  if (oldImage  
                      .isNotEmpty) {  
                    imageUrls =  
                        [oldImage];  
                  }  
                }  

                final remark =  
                    data['Remark']  
                            ?.toString() ??  
                        '';  

                return Card(  
                  margin:  
                      const EdgeInsets  
                          .only(  
                    bottom: 12,  
                  ),  
                  child:  
                      Padding(  
                    padding:  
                        const EdgeInsets  
                            .all(  
                      10,  
                    ),  
                    child:  
                        Row(  
                      children: [  
                        productImagePreview(  
                          imageUrls,  
                        ),  

                        const SizedBox(  
                          width: 12,  
                        ),  

                        Expanded(  
                          child:  
                              Column(  
                            crossAxisAlignment:  
                                CrossAxisAlignment  
                                    .start,  
                            children: [  
                              Text(  
                                name.isEmpty  
                                    ? 'Unnamed Product'  
                                    : name,  
                                style:  
                                    const TextStyle(  
                                  fontWeight:  
                                      FontWeight.bold,  
                                  fontSize:  
                                      16,  
                                ),  
                              ),  

                              const SizedBox(  
                                height:  
                                    4,  
                              ),  

                              Text(  
                                category,  
                              ),  

                              const SizedBox(  
                                height:  
                                    4,  
                              ),  

                              Text(  
                                money(  
                                  price,  
                                ),  
                                style:  
                                    const TextStyle(  
                                  fontWeight:  
                                      FontWeight.bold,  
                                ),  
                              ),  

                              const SizedBox(  
                                height:  
                                    5,  
                              ),  

                              Row(  
                                children: [  
                                  Text(  
                                    stock <=  
                                            0  
                                        ? 'OUT OF STOCK'  
                                        : 'Stock: $stock',  
                                    style:  
                                        TextStyle(  
                                      color: stock <=  
                                              0  
                                          ? Colors.red  
                                          : Colors.green,  
                                      fontWeight:  
                                          FontWeight.bold,  
                                    ),  
                                  ),  

                                  const SizedBox(  
                                    width:  
                                        10,  
                                  ),  

                                  Container(  
                                    padding:  
                                        const EdgeInsets.symmetric(  
                                      horizontal:  
                                          8,  
                                      vertical:  
                                          3,  
                                    ),  
                                    decoration:  
                                        BoxDecoration(  
                                      color: isActive  
                                          ? Colors.green.withOpacity(  
                                              0.1,  
                                            )  
                                          : Colors.grey.withOpacity(  
                                              0.1,  
                                            ),  
                                      borderRadius:  
                                          BorderRadius.circular(  
                                        10,  
                                      ),  
                                    ),  
                                    child:  
                                        Text(  
                                      isActive  
                                          ? 'Active'  
                                          : 'Inactive',  
                                      style:  
                                          TextStyle(  
                                        color: isActive  
                                            ? Colors.green  
                                            : Colors.grey,  
                                        fontSize:  
                                            11,  
                                        fontWeight:  
                                            FontWeight.bold,  
                                      ),  
                                    ),  
                                  ),  
                                ],  
                              ),  

                              if (imageUrls  
                                  .length >  
                                  1)  
                                Padding(  
                                  padding:  
                                      const EdgeInsets.only(  
                                    top:  
                                        4,  
                                  ),  
                                  child:  
                                      Text(  
                                    '${imageUrls.length} product photos',  
                                    style:  
                                        const TextStyle(  
                                      fontSize:  
                                          11,  
                                      color:  
                                          Colors.blue,  
                                    ),  
                                  ),  
                                ),  

                              if (remark  
                                  .trim()  
                                  .isNotEmpty)  
                                Padding(  
                                  padding:  
                                      const EdgeInsets.only(  
                                    top:  
                                        4,  
                                  ),  
                                  child:  
                                      Text(  
                                    'Remark: $remark',  
                                    maxLines:  
                                        1,  
                                    overflow:  
                                        TextOverflow.ellipsis,  
                                    style:  
                                        const TextStyle(  
                                      color:  
                                          Colors.orange,  
                                      fontSize:  
                                          12,  
                                      fontWeight:  
                                          FontWeight.w600,  
                                    ),  
                                  ),  
                                ),  
                            ],  
                          ),  
                        ),  

                        IconButton(  
                          tooltip:  
                              'Delete Product',  
                          icon:  
                              const Icon(  
                            Icons  
                                .delete_outline,  
                            color:  
                                Colors.red,  
                          ),  
                          onPressed:  
                              () {  
                            confirmDelete(  
                              doc.id,  
                              name,  
                            );  
                          },  
                        ),  
                      ],  
                    ),  
                  ),  
                );  
              },  
            ).toList(),  
          );  
        },  
      ),  

      const SizedBox(  
        height: 35,  
      ),  

      // ======================================================  
      // ORDERS HEADER  
      // ======================================================  

      Container(  
        padding:  
            const EdgeInsets.all(  
          20,  
        ),  
        decoration:  
            BoxDecoration(  
          borderRadius:  
              BorderRadius.circular(  
            18,  
          ),  
          gradient:  
              const LinearGradient(  
            colors: [  
              Color(0xff1565C0),  
              Color(0xff42A5F5),  
            ],  
          ),  
        ),  
        child: const Column(  
          crossAxisAlignment:  
              CrossAxisAlignment  
                  .start,  
          children: [  
            Text(  
              'Customer Orders',  
              style:  
                  TextStyle(  
                color:  
                    Colors.white,  
                fontSize: 24,  
                fontWeight:  
                    FontWeight.bold,  
              ),  
            ),  
            SizedBox(  
              height: 6,  
            ),  
            Text(  
              'View and manage customer orders',  
              style:  
                  TextStyle(  
                color:  
                    Colors.white70,  
                fontSize: 14,  
              ),  
            ),  
          ],  
        ),  
      ),  

      const SizedBox(  
        height: 15,  
      ),  

      // ======================================================  
      // ORDERS  
      // ======================================================  

      StreamBuilder<  
          QuerySnapshot<  
              Map<String,  
                  dynamic>>>(  
        stream: ordersRef  
            .orderBy(  
              'createdAt',  
              descending:  
                  true,  
            )  
            .snapshots(),  
        builder:  
            (context, snapshot) {  
          if (snapshot  
                  .connectionState ==  
              ConnectionState  
                  .waiting) {  
            return const Center(  
              child:  
                  CircularProgressIndicator(),  
            );  
          }  

          if (snapshot  
              .hasError) {  
            return Card(  
              child:  
                  Padding(  
                padding:  
                    const EdgeInsets  
                        .all(  
                  16,  
                ),  
                child: Text(  
                  'Orders error:\n'  
                  '${snapshot.error}',  
                ),  
              ),  
            );  
          }  

          final orders =  
              snapshot.data  
                      ?.docs ??  
                  [];  

          if (orders.isEmpty) {  
            return const Card(  
              child:  
                  Padding(  
                padding:  
                    EdgeInsets  
                        .all(  
                  24,  
                ),  
                child:  
                    Center(  
                  child:  
                      Text(  
                    'No customer orders yet.',  
                  ),  
                ),  
              ),  
            );  
          }  

          return Column(  
            children:  
                orders.map(  
              (doc) {  
                final data =  
                    doc.data();  

                final status =  
                    data['status']  
                            ?.toString() ??  
                        'Placed';  

                final name =  
                    data['customerName']  
                            ?.toString() ??  
                        data['name']  
                            ?.toString() ??  
                        'Customer';  

                final mobile =  
                    data['customerMobile']  
                            ?.toString() ??  
                        data['mobile']  
                            ?.toString() ??  
                        data['phone']  
                            ?.toString() ??  
                        '';  

                final email =  
                    data['customerEmail']  
                            ?.toString() ??  
                        data['email']  
                            ?.toString() ??  
                        '';  

                final address =  
                    data['customerAddress']  
                            ?.toString() ??  
                        data['address']  
                            ?.toString() ??  
                        '';  

                final city =  
                    data['customerCity']  
                            ?.toString() ??  
                        data['city']  
                            ?.toString() ??  
                        '';  

                final pincode =  
                    data['customerPincode']  
                            ?.toString() ??  
                        data['pincode']  
                            ?.toString() ??  
                        '';  

                final total =  
                    data['totalAmount'];  

                final createdAt =  
                    data['createdAt'];  

                final items =  
                    data['items'] is List  
                        ? List<dynamic>.from(  
                            data[  
                                'items'],  
                          )  
                        : <dynamic>[];  

                return Card(  
                  margin:  
                      const EdgeInsets  
                          .only(  
                    bottom: 16,  
                  ),  
                  child:  
                      Padding(  
                    padding:  
                        const EdgeInsets  
                            .all(  
                      16,  
                    ),  
                    child:  
                        Column(  
                      crossAxisAlignment:  
                          CrossAxisAlignment  
                              .start,  
                      children: [  
                        Row(  
                          crossAxisAlignment:  
                              CrossAxisAlignment  
                                  .start,  
                          children: [  
                            Expanded(  
                              child:  
                                  Column(  
                                crossAxisAlignment:  
                                    CrossAxisAlignment.start,  
                                children: [  
                                  Text(  
                                    'Order #${doc.id}',  
                                    maxLines:  
                                        1,  
                                    overflow:  
                                        TextOverflow.ellipsis,  
                                    style:  
                                        const TextStyle(  
                                      fontWeight:  
                                          FontWeight.bold,  
                                      fontSize:  
                                          17,  
                                    ),  
                                  ),  
                                  const SizedBox(  
                                    height:  
                                        5,  
                                  ),  
                                  Text(  
                                    formatDate(  
                                      createdAt,  
                                    ),  
                                  ),  
                                ],  
                              ),  
                            ),  

                            Container(  
                              padding:  
                                  const EdgeInsets.symmetric(  
                                horizontal:  
                                    10,  
                                vertical:  
                                    6,  
                              ),  
                              decoration:  
                                  BoxDecoration(  
                                color:  
                                    statusColor(  
                                  status,  
                                ).withOpacity(  
                                  0.12,  
                                ),  
                                borderRadius:  
                                    BorderRadius.circular(  
                                  20,  
                                ),  
                              ),  
                              child:  
                                  Text(  
                                status,  
                                style:  
                                    TextStyle(  
                                  color:  
                                      statusColor(  
                                    status,  
                                  ),  
                                  fontWeight:  
                                      FontWeight.bold,  
                                ),  
                              ),  
                            ),  
                          ],  
                        ),  

                        const Divider(  
                          height:  
                              25,  
                        ),  

                        const Text(  
                          'Customer',  
                          style:  
                              TextStyle(  
                            fontWeight:  
                                FontWeight.bold,  
                            fontSize:  
                                16,  
                          ),  
                        ),  

                        const SizedBox(  
                          height:  
                              8,  
                        ),  

                        Text(  
                          name,  
                          style:  
                              const TextStyle(  
                            fontSize:  
                                15,  
                            fontWeight:  
                                FontWeight.w600,  
                          ),  
                        ),  

                        if (mobile  
                            .isNotEmpty)  
                          Padding(  
                            padding:  
                                const EdgeInsets.only(  
                              top:  
                                  3,  
                            ),  
                            child:  
                                Text(  
                              'Mobile: $mobile',  
                            ),  
                          ),  

                        if (email  
                            .isNotEmpty)  
                          Padding(  
                            padding:  
                                const EdgeInsets.only(  
                              top:  
                                  3,  
                            ),  
                            child:  
                                Text(  
                              'Email: $email',  
                            ),  
                          ),  

                        const SizedBox(  
                          height:  
                              15,  
                        ),  

                        const Text(  
                          'Delivery Address',  
                          style:  
                              TextStyle(  
                            fontWeight:  
                                FontWeight.bold,  
                            fontSize:  
                                16,  
                          ),  
                        ),  

                        const SizedBox(  
                          height:  
                              6,  
                        ),  

                        Text(  
                          [  
                            address,  
                            city,  
                            pincode,  
                          ]  
                              .where(  
                            (value) =>  
                                value.isNotEmpty,  
                          )  
                              .join(  
                            ', ',  
                          ),  
                        ),  

                        const SizedBox(  
                          height:  
                              15,  
                        ),  

                        if (items  
                            .isNotEmpty) ...[  
                          const Text(  
                            'Items',  
                            style:  
                                TextStyle(  
                              fontWeight:  
                                  FontWeight.bold,  
                              fontSize:  
                                  16,  
                            ),  
                          ),  

                          const SizedBox(  
                            height:  
                                7,  
                          ),  

                          ...items.map(  
                            (item) {  
                              if (item  
                                  is! Map) {  
                                return const SizedBox  
                                    .shrink();  
                              }  

                              final itemName =  
                                  item['name']  
                                          ?.toString() ??  
                                      'Product';  

                              final quantity =  
                                  item['quantity']  
                                          ?.toString() ??  
                                      '1';  

                              final itemTotal =  
                                  item['total'];  

                              return Padding(  
                                padding:  
                                    const EdgeInsets.only(  
                                  bottom:  
                                      6,  
                                ),  
                                child:  
                                    Row(  
                                  children: [  
                                    Expanded(  
                                      child:  
                                          Text(  
                                        '$itemName × $quantity',  
                                      ),  
                                    ),  
                                    Text(  
                                      money(  
                                        itemTotal,  
                                      ),  
                                      style:  
                                          const TextStyle(  
                                        fontWeight:  
                                            FontWeight.w600,  
                                      ),  
                                    ),  
                                  ],  
                                ),  
                              );  
                            },  
                          ),  
                        ],  

                        const Divider(  
                          height:  
                              25,  
                        ),  

                        Row(  
                          mainAxisAlignment:  
                              MainAxisAlignment  
                                  .spaceBetween,  
                          children: [  
                            const Text(  
                              'Order Total',  
                              style:  
                                  TextStyle(  
                                fontSize:  
                                    18,  
                                fontWeight:  
                                    FontWeight.bold,  
                              ),  
                            ),  
                            Text(  
                              money(  
                                total,  
                              ),  
                              style:  
                                  const TextStyle(  
                                fontSize:  
                                    21,  
                                fontWeight:  
                                    FontWeight.bold,  
                              ),  
                            ),  
                          ],  
                        ),  

                        const SizedBox(  
                          height:  
                              15,  
                        ),  

                        DropdownButtonFormField<  
                            String>(  
                          initialValue:  
                              orderStatuses.contains(  
                            status,  
                          )  
                                  ? status  
                                  : 'Placed',  
                          decoration:  
                              const InputDecoration(  
                            labelText:  
                                'Order Status',  
                            border:  
                                OutlineInputBorder(),  
                          ),  
                          items:  
                              orderStatuses  
                                  .map(  
                            (  
                              statusValue,  
                            ) {  
                              return DropdownMenuItem<  
                                  String>(  
                                value:  
                                    statusValue,  
                                child:  
                                    Row(  
                                  children: [  
                                    Icon(  
                                      Icons  
                                          .circle,  
                                      size:  
                                          10,  
                                      color:  
                                          statusColor(  
                                        statusValue,  
                                      ),  
                                    ),  
                                    const SizedBox(  
                                      width:  
                                          8,  
                                    ),  
                                    Text(  
                                      statusValue,  
                                    ),  
                                  ],  
                                ),  
                              );  
                            },  
                          ).toList(),  
                          onChanged:  
                              (value) {  
                            if (value ==  
                                    null ||  
                                value ==  
                                    status) {  
                              return;  
                            }  

                            updateOrderStatus(  
                              doc.id,  
                              value,  
                            );  
                          },  
                        ),  
                      ],  
                    ),  
                  ),  
                );  
              },  
            ).toList(),  
          );  
        },  
      ),  

      const SizedBox(  
        height: 30,  
      ),  
    ],  
  ),  
);

}
}
