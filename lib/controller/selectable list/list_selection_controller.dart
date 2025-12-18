import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ListSelectionController extends GetxController {
  final RxSet<String> selectedIndexes = <String>{}.obs;
  final RxBool selected = false.obs;

  void toggleSelection(String index) {
    if (selectedIndexes.contains(index)) {
      selectedIndexes.remove(index);
      debugPrint('remove called');
    } else {
      selectedIndexes.add(index);
      selected.value = true;
      debugPrint('add called');
    }
    // update();
  }

  Future<void> deleteChats() async {
    FirebaseFirestore firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();
    if (selectedIndexes.isNotEmpty) {
      for (final String communityUid in selectedIndexes) {
        debugPrint('community deleted: $communityUid');
        batch.delete(firestore.collection('community').doc(communityUid));
      }
      for (final String groupUid in selectedIndexes) {
        debugPrint('Group deleted: $groupUid');
        batch.delete(firestore.collection('groups').doc(groupUid));
      }
      for (final String userUid in selectedIndexes) {
        batch.delete(firestore
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .collection('chats')
            .doc(userUid));
      }

      try {
        await batch.commit();
        debugPrint('Successful');
      } catch (e) {
        debugPrint('error: $e');
      }
    }
  }

  bool isSelected(String index) {
    if(selectedIndexes.contains(index)){
      return true;
    }else{
      return false;
    }
    
  }
}
