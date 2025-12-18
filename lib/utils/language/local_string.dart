// ignore_for_file: equal_keys_in_map

import 'package:get/get.dart';

import '../strings.dart';
import 'english.dart';
import 'indonesian.dart';

class LocalString extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
        //English
        'en_US': {
          Strings.online: English.online,
          Strings.offline: English.offline,
          Strings.me: English.me,
          Strings.opposite: English.opposite,
          Strings.typeAMessage: English.typeAMessage,
          Strings.appName: English.appName,
          Strings.appVersion: English.appVersion,
          Strings.dot: English.dot,
          Strings.welcome: English.welcome,
          Strings.agree: English.agree,
          Strings.readOur: English.readOur,
          Strings.privacyPolicy: English.privacyPolicy,
          Strings.tapAgree: English.tapAgree,
          Strings.termsOfService: English.termsOfService,
          Strings.enterYourPhoneNumber: English.enterYourPhoneNumber,
          Strings.verifyYourPhoneNumber: English.verifyYourPhoneNumber,
          Strings.whatsMynum: English.whatsMynum,
          Strings.carrierCharge: English.carrierCharge,
          Strings.chat: English.chat,
          Strings.status: English.status,
          Strings.calls: English.calls,
          Strings.advertiseOnFb: English.advertiseOnFb,
          Strings.businesstools: English.businesstools,
          Strings.newGroup: English.newGroup,
          Strings.newBroacast: English.newBroacast,
          Strings.linkedDevices: English.linkedDevices,
          Strings.starredMessages: English.starredMessages,
          Strings.starredMessageSubTitle: English.starredMessageSubTitle,
          Strings.settings: English.settings,
          Strings.deleteAll: English.deleteAll,
          Strings.profile: English.profile,
          Strings.profileInfo: English.profileInfo,
          Strings.viewContact: English.viewContact,
          Strings.mediaLinksAndDocs: English.mediaLinksAndDocs,
          Strings.whatsappWeb: English.whatsappWeb,
          Strings.search: English.search,
          Strings.muteNotification: English.muteNotification,
          Strings.disappearingMessages: English.disappearingMessages,
          Strings.wallpaper: English.wallpaper,
          Strings.statusPrivacy: English.statusPrivacy,
          Strings.clearCallLog: English.clearCallLog,

          Strings.document: English.document,
          Strings.camera: English.camera,
          Strings.gallery: English.gallery,
          Strings.audio: English.audio,
          Strings.location: English.location,
          Strings.poll: English.poll,
          Strings.contact: English.contact,

          Strings.minutesAgo: English.minutesAgo,
          Strings.mutedUpdates: English.mutedUpdates,

          // log in

          Strings.phoneNumber: English.phoneNumber,
          Strings.next: English.next,

          //otp

          Strings.verifyingYourNum: English.verifyingYourNum,
          Strings.weHaveSent: English.weHaveSent,
          Strings.didntReceiveCode: English.didntReceiveCode,
          Strings.enterSixDCode: English.enterSixDCode,

          // 'Select contact'
          Strings.selectContact: English.selectContact,
          Strings.inviteAFrind: English.inviteAFrind,
          Strings.contacts: English.contacts,
          Strings.refresh: English.refresh,
          Strings.help: English.help,

          //group
          Strings.createGroup: English.createGroup,
          Strings.enterGroupName: English.enterGroupName,
          Strings.addParticipants: English.addParticipants,
          Strings.alreadyAddToGroup: English.alreadyAddToGroup,
          Strings.tapHareForGroupInfo: English.tapHareForGroupInfo,

          //settings

          Strings.from: English.from,
          Strings.account: English.account,
          Strings.accountSubTitle: English.accountSubTitle,
          Strings.avatar: English.avatar,
          Strings.avatarSubTitle: English.avatarSubTitle,
          Strings.privacy: English.privacy,
          Strings.privacySubTitle: English.privacySubTitle,
          Strings.chats: English.chats,
          Strings.chatsSubTitle: English.chatsSubTitle,
          Strings.notification: English.notification,
          Strings.notificationSubTitle: English.notificationSubTitle,
          Strings.storageAndData: English.storageAndData,
          Strings.storageAndDataSubTitle: English.storageAndDataSubTitle,
          Strings.appLanguage: English.appLanguage,
          Strings.appLanguageSubTitle: English.appLanguageSubTitle,
          Strings.helpSubTitle: English.helpSubTitle,

          //profile

          Strings.cancel: English.cancel,
          Strings.save: English.save,
          Strings.name: English.name,
          Strings.nameHint: English.nameHint,
          Strings.about: English.about,
          Strings.phone: English.phone,
          Strings.profilePhoto: English.profilePhoto,
          Strings.enterYourName: English.enterYourName,
          Strings.enterYourEmail: English.enterYourEmail,
          Strings.enterYourNames: English.enterYourNames,
          Strings.pleaseProvide: English.pleaseProvide,

          //account
          Strings.securityNotification: English.securityNotification,
          Strings.twoStepVerification: English.twoStepVerification,
          Strings.chnageNumber: English.chnageNumber,
          Strings.requestAccountInfo: English.requestAccountInfo,
          Strings.deleteMyAccount: English.deleteMyAccount,

          // status
          Strings.myStatus: English.myStatus,
          Strings.tapToAddStatusUpdate: English.tapToAddStatusUpdate,

          // community
          Strings.startYourCommunity: English.startYourCommunity,
          Strings.introducingCommunities: English.introducingCommunities,
          Strings.easilyOrganize: English.easilyOrganize,

// call
          Strings.createCallLink: English.createCallLink,
          Strings.recent: English.recent,
          Strings.shareAlink: English.shareAlink,

          //  chats
          Strings.enterIsSend: English.enterIsSend,
          Strings.chatsSettings: English.chatsSettings,
          Strings.mediaVisibility: English.mediaVisibility,
          Strings.fontSize: English.fontSize,
          Strings.medium: English.medium,
          Strings.archivedChats: English.archivedChats,
          Strings.keepChatsArchived: English.keepChatsArchived,
          Strings.archivedRemain: English.archivedRemain,
          Strings.chatBackup: English.chatBackup,
          Strings.chatsHistory: English.chatsHistory,
          Strings.theme: English.theme,
          Strings.dark: English.dark,
          Strings.light: English.light,
          Strings.systemDefault: English.systemDefault,
          Strings.ok: English.ok,
          Strings.more: English.more,
          Strings.chooseTheme: English.chooseTheme,
          Strings.display: English.display,
          Strings.enterKeyWillSendYouMessage:
              English.enterKeyWillSendYouMessage,
          Strings.showNewly: English.showNewly,
          Strings.currentlySetTo: English.currentlySetTo,
          Strings.selectAbout: English.selectAbout,

          //language
          Strings.english: English.english,
          Strings.indonesian: English.indonesian,
          Strings.changeLanguage: English.changeLanguage,
          Strings.createAnAccount: English.createAnAccount,
          Strings.demoUser: English.demoUser,
          Strings.contactsOn: English.contactsOn,
          Strings.inviteTo: English.inviteTo,
          Strings.noCallData: English.noCallData,
          Strings.noStatusText: English.noStatusText,
          Strings.deleteAccount: English.deleteAccount,
          Strings.yes: English.yes,
          Strings.no: English.no,

          Strings.createCommunity: English.createCommunity,
          Strings.newCommunity: English.newCommunity,
          Strings.selectGroup: English.selectGroup,
          Strings.groups: English.groups,
          Strings.communityName: English.communityName,
          Strings.communityDefaultHeadline: English.communityDefaultHeadline,
          Strings.addGroup: English.addGroup,
          Strings.creatingCommunity: English.creatingCommunity,
          Strings.pleaseWaitAMoment: English.pleaseWaitAMoment,
          Strings.removingGroup: English.removingGroup,
          Strings.deletingCommunity: English.deletingCommunity,
          Strings.announcements: English.announcements,
          Strings.addGroups: English.addGroups,
          Strings.community: English.community,
          Strings.group: English.group,
          Strings.viewAll: English.viewAll,
          Strings.remove: English.remove,
          Strings.deleteCommunity: English.deleteCommunity,
          Strings.removeGroupTitle: English.removeGroupTitle,
          Strings.groupsYouAdmin: English.groupsYouAdmin,
          Strings.welcomeToYourCommunity: English.welcomeToYourCommunity,
          Strings.alreadyAddToCommunity: English.alreadyAddToCommunity,
          Strings.deleteCommunityAlert: English.deleteCommunityAlert,
          Strings.groupAdded: English.groupAdded
        },

        //Indonesian
        'id_ID': {
          Strings.online: Indonesian.online,
          Strings.offline: Indonesian.offline,
          Strings.me: Indonesian.me,
          Strings.opposite: Indonesian.opposite,
          Strings.typeAMessage: Indonesian.typeAMessage,
          Strings.appName: Indonesian.appName,
          Strings.appVersion: Indonesian.appVersion,
          Strings.dot: Indonesian.dot,
          Strings.welcome: Indonesian.welcome,
          Strings.agree: Indonesian.agree,
          Strings.readOur: Indonesian.readOur,
          Strings.privacyPolicy: Indonesian.privacyPolicy,
          Strings.tapAgree: Indonesian.tapAgree,
          Strings.termsOfService: Indonesian.termsOfService,
          Strings.enterYourPhoneNumber: Indonesian.enterYourPhoneNumber,
          Strings.verifyYourPhoneNumber: Indonesian.verifyYourPhoneNumber,
          Strings.whatsMynum: Indonesian.whatsMynum,
          Strings.carrierCharge: Indonesian.carrierCharge,
          Strings.chat: Indonesian.chat,
          Strings.status: Indonesian.status,
          Strings.calls: Indonesian.calls,
          Strings.advertiseOnFb: Indonesian.advertiseOnFb,
          Strings.businesstools: Indonesian.businesstools,
          Strings.newGroup: Indonesian.newGroup,
          Strings.newBroacast: Indonesian.newBroacast,
          Strings.linkedDevices: Indonesian.linkedDevices,
          Strings.starredMessages: Indonesian.starredMessages,
          Strings.starredMessageSubTitle: Indonesian.starredMessageSubTitle,
          Strings.settings: Indonesian.settings,
          Strings.deleteAll: Indonesian.deleteAll,
          Strings.profile: Indonesian.profile,
          Strings.profileInfo: Indonesian.profileInfo,
          Strings.viewContact: Indonesian.viewContact,
          Strings.mediaLinksAndDocs: Indonesian.mediaLinksAndDocs,
          Strings.whatsappWeb: Indonesian.whatsappWeb,
          Strings.search: Indonesian.search,
          Strings.muteNotification: Indonesian.muteNotification,
          Strings.disappearingMessages: Indonesian.disappearingMessages,
          Strings.wallpaper: Indonesian.wallpaper,
          Strings.statusPrivacy: Indonesian.statusPrivacy,
          Strings.clearCallLog: Indonesian.clearCallLog,

          Strings.document: Indonesian.document,
          Strings.camera: Indonesian.camera,
          Strings.gallery: Indonesian.gallery,
          Strings.audio: Indonesian.audio,
          Strings.location: Indonesian.location,
          Strings.poll: Indonesian.poll,
          Strings.contact: Indonesian.contact,

          Strings.minutesAgo: Indonesian.minutesAgo,
          Strings.mutedUpdates: Indonesian.mutedUpdates,

          // log in

          Strings.phoneNumber: Indonesian.phoneNumber,
          Strings.next: Indonesian.next,

          //otp

          Strings.verifyingYourNum: Indonesian.verifyingYourNum,
          Strings.weHaveSent: Indonesian.weHaveSent,
          Strings.didntReceiveCode: Indonesian.didntReceiveCode,
          Strings.enterSixDCode: Indonesian.enterSixDCode,

          // 'Select contact'
          Strings.selectContact: Indonesian.selectContact,
          Strings.inviteAFrind: Indonesian.inviteAFrind,
          Strings.contacts: Indonesian.contacts,
          Strings.refresh: Indonesian.refresh,
          Strings.help: Indonesian.help,

          //group
          Strings.createGroup: Indonesian.createGroup,
          Strings.enterGroupName: Indonesian.enterGroupName,
          Strings.addParticipants: Indonesian.addParticipants,
          Strings.alreadyAddToGroup: Indonesian.alreadyAddToGroup,
          Strings.tapHareForGroupInfo: Indonesian.tapHareForGroupInfo,

          //settings

          Strings.from: Indonesian.from,
          Strings.account: Indonesian.account,
          Strings.accountSubTitle: Indonesian.accountSubTitle,
          Strings.avatar: Indonesian.avatar,
          Strings.avatarSubTitle: Indonesian.avatarSubTitle,
          Strings.privacy: Indonesian.privacy,
          Strings.privacySubTitle: Indonesian.privacySubTitle,
          Strings.chats: Indonesian.chats,
          Strings.chatsSubTitle: Indonesian.chatsSubTitle,
          Strings.notification: Indonesian.notification,
          Strings.notificationSubTitle: Indonesian.notificationSubTitle,
          Strings.storageAndData: Indonesian.storageAndData,
          Strings.storageAndDataSubTitle: Indonesian.storageAndDataSubTitle,
          Strings.appLanguage: Indonesian.appLanguage,
          Strings.appLanguageSubTitle: Indonesian.appLanguageSubTitle,
          Strings.helpSubTitle: Indonesian.helpSubTitle,

          //profile

          Strings.cancel: Indonesian.cancel,
          Strings.save: Indonesian.save,
          Strings.name: Indonesian.name,
          Strings.nameHint: Indonesian.nameHint,
          Strings.about: Indonesian.about,
          Strings.phone: Indonesian.phone,
          Strings.profilePhoto: Indonesian.profilePhoto,
          Strings.enterYourName: Indonesian.enterYourName,
          Strings.enterYourEmail: Indonesian.enterYourEmail,
          Strings.enterYourNames: Indonesian.enterYourNames,
          Strings.pleaseProvide: Indonesian.pleaseProvide,

          //account
          Strings.securityNotification: Indonesian.securityNotification,
          Strings.twoStepVerification: Indonesian.twoStepVerification,
          Strings.chnageNumber: Indonesian.chnageNumber,
          Strings.requestAccountInfo: Indonesian.requestAccountInfo,
          Strings.deleteMyAccount: Indonesian.deleteMyAccount,

          // status
          Strings.myStatus: Indonesian.myStatus,
          Strings.tapToAddStatusUpdate: Indonesian.tapToAddStatusUpdate,

          // community
          Strings.startYourCommunity: Indonesian.startYourCommunity,
          Strings.introducingCommunities: Indonesian.introducingCommunities,
          Strings.easilyOrganize: Indonesian.easilyOrganize,

// call
          Strings.createCallLink: Indonesian.createCallLink,
          Strings.recent: Indonesian.recent,
          Strings.shareAlink: Indonesian.shareAlink,

          //  chats
          Strings.enterIsSend: Indonesian.enterIsSend,
          Strings.chatsSettings: Indonesian.chatsSettings,
          Strings.mediaVisibility: Indonesian.mediaVisibility,
          Strings.fontSize: Indonesian.fontSize,
          Strings.medium: Indonesian.medium,
          Strings.archivedChats: Indonesian.archivedChats,
          Strings.keepChatsArchived: Indonesian.keepChatsArchived,
          Strings.archivedRemain: Indonesian.archivedRemain,
          Strings.chatBackup: Indonesian.chatBackup,
          Strings.chatsHistory: Indonesian.chatsHistory,
          Strings.theme: Indonesian.theme,
          Strings.dark: Indonesian.dark,
          Strings.light: Indonesian.light,
          Strings.systemDefault: Indonesian.systemDefault,
          Strings.ok: Indonesian.ok,
          Strings.more: Indonesian.more,
          Strings.chooseTheme: Indonesian.chooseTheme,
          Strings.display: Indonesian.display,
          Strings.enterKeyWillSendYouMessage:
              Indonesian.enterKeyWillSendYouMessage,
          Strings.showNewly: Indonesian.showNewly,
          Strings.currentlySetTo: Indonesian.currentlySetTo,
          Strings.selectAbout: Indonesian.selectAbout,

          //language Indonesian
          Strings.english: Indonesian.english,
          Strings.indonesian: Indonesian.indonesian,
          Strings.changeLanguage: Indonesian.changeLanguage,
          Strings.createAnAccount: Indonesian.createAnAccount,
          Strings.demoUser: Indonesian.demoUser,
          Strings.contactsOn: Indonesian.contactsOn,
          Strings.inviteTo: Indonesian.inviteTo,
          Strings.noCallData: Indonesian.noCallData,
          Strings.noStatusText: Indonesian.noStatusText,
          Strings.deleteAccount: Indonesian.deleteAccount,
          Strings.yes: Indonesian.yes,
          Strings.no: Indonesian.no,
          Strings.createCommunity: Indonesian.createCommunity,
          Strings.newCommunity: Indonesian.newCommunity,
          Strings.selectGroup: Indonesian.selectGroup,
          Strings.groups: Indonesian.groups,
          Strings.communityName: Indonesian.communityName,
          Strings.communityDefaultHeadline: Indonesian.communityDefaultHeadline,
          Strings.addGroup: Indonesian.addGroup,
          Strings.creatingCommunity: Indonesian.creatingCommunity,
          Strings.pleaseWaitAMoment: Indonesian.pleaseWaitAMoment,
          Strings.removingGroup: Indonesian.removingGroup,
          Strings.deletingCommunity: Indonesian.deletingCommunity,
          Strings.announcements: Indonesian.announcements,
          Strings.addGroups: Indonesian.addGroups,
          Strings.community: Indonesian.community,
          Strings.group: Indonesian.group,
          Strings.viewAll: Indonesian.viewAll,
          Strings.remove: Indonesian.remove,
          Strings.deleteCommunity: Indonesian.deleteCommunity,
          Strings.removeGroupTitle: Indonesian.removeGroupTitle,
          Strings.groupsYouAdmin: Indonesian.groupsYouAdmin,
          Strings.welcomeToYourCommunity: Indonesian.welcomeToYourCommunity,
          Strings.alreadyAddToCommunity: Indonesian.alreadyAddToCommunity,
          Strings.deleteCommunityAlert: Indonesian.deleteCommunityAlert,
          Strings.groupAdded: Indonesian.groupAdded
        },
      };
}
