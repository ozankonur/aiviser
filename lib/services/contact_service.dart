import 'package:contacts_service/contacts_service.dart';
import 'package:permission_handler/permission_handler.dart';

class ContactService {
  Future<List<Contact>> getContacts() async {
    if (await Permission.contacts.request().isGranted) {
      return await ContactsService.getContacts();
    } else {
      throw Exception('Contacts permission not granted');
    }
  }

  Future<List<Contact>> getContactsWithPhoneNumbers() async {
    List<Contact> allContacts = await getContacts();
    return allContacts.where((contact) => contact.phones!.isNotEmpty).toList();
  }

  String formatPhoneNumber(String phoneNumber) {
    // Remove all non-digit characters
    String digitsOnly = phoneNumber.replaceAll(RegExp(r'\D'), '');
    
    // Ensure the number starts with a country code (e.g., +1 for US)
    if (!digitsOnly.startsWith('+')) {
      digitsOnly = '+1$digitsOnly'; // Assuming US numbers, change as needed
    }
    
    return digitsOnly;
  }
}