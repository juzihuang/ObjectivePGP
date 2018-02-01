//
//  ObjectivePGPTests.m
//  ObjectivePGPTests
//
//  Copyright (c) Marcin Krzyżanowski. All rights reserved.
//
//  THIS SOURCE CODE AND ANY ACCOMPANYING DOCUMENTATION ARE PROTECTED BY
//  INTERNATIONAL COPYRIGHT LAW. USAGE IS BOUND TO THE LICENSE AGREEMENT.
//  This notice may not be removed from this file.
//

#import <ObjectivePGP/ObjectivePGP.h>
#import "PGPMacros+Private.h"
#import "PGPTestUtils.h"
#import <XCTest/XCTest.h>

// sec   2048R/AEEF64C8 2014-05-03
// uid                  Marcin Krzyzanowski (Test keys) <test+marcin.krzyzanowski@gmail.com>
// ssb   2048R/7D4FCA45 2014-05-03

// pub   2048R/AEEF64C8 2014-05-03
// Key fingerprint = 816E 6A80 8067 D41E 4CB0  3FCC 9469 0093 AEEF 64C8
// uid                  Marcin Krzyzanowski (Test keys) <test+marcin.krzyzanowski@gmail.com>
// sub   2048R/7D4FCA45 2014-05-03

// pass ObjectivePGP

@interface ObjectivePGPTests : XCTestCase

@property (nonatomic, readonly) NSBundle *bundle;

@end

@implementation ObjectivePGPTests

- (void)setUp {
    [super setUp];

    _bundle = PGPTestUtils.filesBundle;
}

- (void)tearDown {
    [super tearDown];
}

- (void)testGenerateNewKey {
    let keyGenerator = [[PGPKeyGenerator alloc] init];
    let key = [keyGenerator generateFor:@"Marcin <marcin@example.com>" passphrase:nil];
    XCTAssertNotNil(key);

    // test sign
    let dataToSign = [@"objectivepgp" dataUsingEncoding:NSUTF8StringEncoding];

    let sign = [ObjectivePGP sign:dataToSign detached:YES usingKeys:@[key] passphraseForKey:nil error:nil];
    XCTAssertNotNil(sign);

    BOOL isVerified = [ObjectivePGP verify:dataToSign withSignature:sign usingKeys:@[key] passphraseForKey:nil error:nil];
    XCTAssertTrue(isVerified);

    // test export
    let exportedPublicKeyData = [key export:PGPKeyTypePublic error:nil];
    XCTAssertNotNil(exportedPublicKeyData);
    let exportedSecretKeyData = [key export:PGPKeyTypeSecret error:nil];
    XCTAssertNotNil(exportedSecretKeyData);

    let importedKeys = [ObjectivePGP readKeysFromData:exportedPublicKeyData error:nil];
    XCTAssert(importedKeys.count == 1);
    XCTAssertEqualObjects(importedKeys.firstObject.keyID, key.keyID);
}

- (void)testGenerateNewKeyWithPassphrase {
    let keyGenerator = [[PGPKeyGenerator alloc] init];
    let key = [keyGenerator generateFor:@"Marcin <marcin@example.com>" passphrase:@"1234567890"];
    XCTAssertNotNil(key);

    let exportedPublicKeyData = [key export:PGPKeyTypePublic error:nil];
    XCTAssertNotNil(exportedPublicKeyData);
    let exportedSecretKeyData = [key export:PGPKeyTypeSecret error:nil];
    XCTAssertNotNil(exportedSecretKeyData);

    let importedPublicKeys = [ObjectivePGP readKeysFromData:exportedPublicKeyData error:nil];
    XCTAssert(importedPublicKeys.count == 1);

    let importedSecretKeys = [ObjectivePGP readKeysFromData:exportedPublicKeyData error:nil];
    XCTAssert(importedSecretKeys.count == 1);
}

- (void)testNotDuplicates {
    let keyring1 = [[PGPKeyring alloc] init];
    [keyring1 importKeys:[PGPTestUtils readKeysFromPath:@"pubring-test-plaintext.gpg"]];
    NSUInteger count1 = keyring1.keys.count;

    let keyring2 = [[PGPKeyring alloc] init];
    [keyring2 importKeys:[PGPTestUtils readKeysFromPath:@"pubring-test-plaintext.gpg"]];
    NSUInteger count2 = keyring2.keys.count;

    XCTAssertEqual(count1, count2);
}

- (void)testKeyEquality {
    let keyring = [[PGPKeyring alloc] init];
    [keyring importKeys:[PGPTestUtils readKeysFromPath:@"pubring-test-plaintext.gpg"]];
    [keyring importKeys:[PGPTestUtils readKeysFromPath:@"pubring-test-encrypted.gpg"]];
    [keyring importKeys:[PGPTestUtils readKeysFromPath:@"secring-test-plaintext.gpg"]];
    [keyring importKeys:[PGPTestUtils readKeysFromPath:@"secring-test-encrypted.gpg"]];
    let encryptedKey = [keyring findKeyWithIdentifier:@"9528AAA17A9BC007"];
    XCTAssertNotNil(encryptedKey);
    XCTAssertTrue(encryptedKey.isEncryptedWithPassword);
    NSError *error;

    let decryptedKey = [encryptedKey decryptedWithPassphrase:@"1234" error:&error];
    XCTAssertFalse(decryptedKey.isEncryptedWithPassword);
    XCTAssertNotNil(decryptedKey);
    let decryptedKey2 = [encryptedKey decryptedWithPassphrase:@"12345" error:&error];
    XCTAssertTrue(encryptedKey.isEncryptedWithPassword);
    XCTAssertNil(decryptedKey2);

    XCTAssertTrue([keyring.keys containsObject:encryptedKey]);
}


- (void)testExportImport {
    let keyring = [[PGPKeyring alloc] init];
    [keyring importKeys:[PGPTestUtils readKeysFromPath:@"pubring-test-plaintext.gpg"]];
    [keyring importKeys:[PGPTestUtils readKeysFromPath:@"pubring-test-encrypted.gpg"]];
    [keyring importKeys:[PGPTestUtils readKeysFromPath:@"secring-test-plaintext.gpg"]];
    [keyring importKeys:[PGPTestUtils readKeysFromPath:@"secring-test-encrypted.gpg"]];

    XCTAssertNotNil(keyring.keys.firstObject);
    NSUInteger keysCount = keyring.keys.count;

    for (PGPKey *key in keyring.keys) {
        let exportedKeyData = [key export:nil];
        let readKeys = [ObjectivePGP readKeysFromData:exportedKeyData error:nil];
        XCTAssertTrue(readKeys.count == 1);
        [keyring importKeys:readKeys];
    }

    XCTAssertEqual(keyring.keys.count, keysCount);
}

// https://github.com/krzyzanowskim/ObjectivePGP/issues/22
- (void)testIssue22 {
    let keyring = [[PGPKeyring alloc] init];
    [keyring importKeys:[PGPTestUtils readKeysFromPath:@"issue22-original.asc"]];
    let key = [keyring.keys firstObject];

    NSError *err = nil;
    PGPPartialKey * _Nullable decryptedKey = [key.secretKey decryptedWithPassphrase:@"weakpassphrase" error:&err];
    XCTAssertNotNil(decryptedKey);
    NSData *exportedKeyData = [decryptedKey export:nil];
    XCTAssertEqual(exportedKeyData.length, (NSUInteger)4869);
    XCTAssertEqual(keyring.keys.count, (NSUInteger)1);
}

- (void)testIssue35 {
    let messagePath = [PGPTestUtils pathToBundledFile:@"issue35-message.asc"];
    let keys = [PGPTestUtils readKeysFromPath:@"issue35-key.asc"];
    NSError *error = nil;
    [ObjectivePGP decrypt:[NSData dataWithContentsOfFile:messagePath] andVerifySignature:YES usingKeys:keys passphraseForKey:nil error:&error];
}

// https://github.com/krzyzanowskim/ObjectivePGP/issues/53
- (void)testIssue53GNUDummyS2K {
    let keyring = [[PGPKeyring alloc] init];
    [keyring importKeys:[PGPTestUtils readKeysFromPath:@"issue53-s2k-gnu-dummy.prv.asc"]];
    [keyring importKeys:[PGPTestUtils readKeysFromPath:@"issue53-s2k-gnu-dummy.pub.asc"]];
    XCTAssertTrue(keyring.keys.count > 0);
}

// https://github.com/krzyzanowskim/ObjectivePGP/issues/44
- (void)testIssue44 {
    let keyring = [[PGPKeyring alloc] init];
    [keyring importKeys:[PGPTestUtils readKeysFromPath:@"issue44-keys.asc"]];

    XCTAssertEqual(keyring.keys.count, (NSUInteger)1);

    let keyToSign = [keyring findKeyWithIdentifier:@"71180E514EF122E5"];
    XCTAssertNotNil(keyToSign);

    let signatureData = [NSData dataWithContentsOfFile:[PGPTestUtils pathToBundledFile:@"issue44-keys.asc"]];
    let signature = [ObjectivePGP sign:signatureData detached:YES usingKeys:@[keyToSign] passphraseForKey:^NSString * _Nullable(PGPKey *k) { return @"passphrase"; } error:nil];
    XCTAssertNotNil(signature);
}

// https://github.com/krzyzanowskim/ObjectivePGP/issues/62
- (void)testIssue62 {
    let keyring = [[PGPKeyring alloc] init];
    [keyring importKeys:[PGPTestUtils readKeysFromPath:@"issue62-keys.asc"]];
    XCTAssertEqual(keyring.keys.count, (NSUInteger)1);

    let data = [NSData dataWithContentsOfFile:[PGPTestUtils pathToBundledFile:@"issue62-message.asc"]];
    NSError *decryptError1;
    let decryptedData1 = [ObjectivePGP decrypt:data andVerifySignature:YES usingKeys:keyring.keys passphraseForKey:nil error:&decryptError1];
    XCTAssertNotNil(decryptedData1);
    XCTAssertNotNil(decryptError1);
}

// https://github.com/krzyzanowskim/ObjectivePGP/issues/59
- (void)testIssue59 {
    let keys = [PGPTestUtils readKeysFromPath:@"issue59-keys.asc"];
    XCTAssertEqual(keys.count, (NSUInteger)1);
}

- (void)testIssue77EncryptionKey {
    let keyring = [[PGPKeyring alloc] init];
    let generator = [[PGPKeyGenerator alloc] init];
    let key = [generator generateFor:@"marcin77@example.com" passphrase:@"test"];
    NSError *err;
    let publicKeyData = [key export:PGPKeyTypePublic error:&err];
    let secretKeyData = [key export:PGPKeyTypeSecret error:&err];

    let publicKeys = [ObjectivePGP readKeysFromData:publicKeyData error:nil];
    let secretKeys = [ObjectivePGP readKeysFromData:secretKeyData error:nil];
    [keyring importKeys:@[publicKeys.firstObject, secretKeys.firstObject]];

    let message = [@"test message" dataUsingEncoding:NSUTF8StringEncoding];

    NSError *encryptError;
    let encryptedMessage = [ObjectivePGP encrypt:message addSignature:NO usingKeys:publicKeys passphraseForKey:nil error:&encryptError];

    NSError *decryptError1;
    let decryptedMessage1 = [ObjectivePGP decrypt:encryptedMessage andVerifySignature:YES usingKeys:keyring.keys passphraseForKey:nil error:&decryptError1];
    XCTAssertEqualObjects(decryptedMessage1, nil);


    NSError *decryptError2;
    let decryptedMessage2 = [ObjectivePGP decrypt:encryptedMessage andVerifySignature:YES usingKeys:keyring.keys passphraseForKey:^NSString * _Nullable(PGPKey *k) { return @"test"; } error:&decryptError2];
    XCTAssertEqualObjects(decryptedMessage2, message);
}

- (void)testIssue82KeysEquality {
    let keys1 = [PGPTestUtils readKeysFromPath:@"issue82-keys.asc"];
    let keys2 = [PGPTestUtils readKeysFromPath:@"issue82-keys.asc"];
    XCTAssertEqualObjects(keys1, keys2);
}

- (void)testIssue88VerifyFromThunderbird {
    let keyring = [[PGPKeyring alloc] init];

    let pubKeys = [PGPTestUtils readKeysFromPath:@"issue88-pub.asc"];
    let secKeys = [PGPTestUtils readKeysFromPath:@"issue88-sec.asc"];

    [keyring importKeys:pubKeys];
    [keyring importKeys:secKeys];

    let messagePath = [PGPTestUtils pathToBundledFile:@"issue88-message.asc"];
    let messageData = [NSData dataWithContentsOfFile:messagePath];
    NSError *verifyError = nil;
    BOOL verified = [ObjectivePGP verify:messageData withSignature:nil usingKeys:keyring.keys passphraseForKey:nil error:&verifyError];
    XCTAssertNil(verifyError);
    XCTAssertTrue(verified);

    NSError *decryptError = nil;
    let decrypted = [ObjectivePGP decrypt:messageData andVerifySignature:YES usingKeys:keyring.keys passphraseForKey:nil error:&decryptError];
    // let txt = [[NSString alloc] initWithData:decrypted encoding:NSUTF8StringEncoding];
    XCTAssertNotNil(decrypted);
    XCTAssertNil(decryptError);
}

// https://github.com/krzyzanowskim/ObjectivePGP/issues/84
// Embedded signatures code seems to have broken reading keys
- (void)testIssue84EmbeddedSignatures {
    // Input data is broken. Embeded signature has invalid data, ignore and load key anyway.
    let keys = [PGPTestUtils readKeysFromPath:@"issue84-key.asc"];
    XCTAssertEqual(keys.count, (NSUInteger)1);
}

// Symmetrically Encrypted Data Packet (Tag 9)
- (void)testIssue91Tag9 {
    let keyring = [[PGPKeyring alloc] init];
    let pubKeys = [PGPTestUtils readKeysFromPath:@"issue91-pub.asc"];
    let secKeys = [PGPTestUtils readKeysFromPath:@"issue91-sec.asc"];

    let messagePath = [PGPTestUtils pathToBundledFile:@"issue91-message.asc"];
    let messageData = [NSData dataWithContentsOfFile:messagePath];

    [keyring importKeys:pubKeys];
    [keyring importKeys:secKeys];
    NSError *decryptError = nil;
    let decrypted = [ObjectivePGP decrypt:messageData andVerifySignature:YES usingKeys:keyring.keys passphraseForKey:^NSString * _Nullable(PGPKey *k) { return @"abcd"; } error:&decryptError];
    XCTAssertNotNil(decrypted);
    XCTAssertNotNil(decryptError); // not signed
}

// https://github.com/krzyzanowskim/ObjectivePGP/issues/93
// Public Key is invalid input data but key works in android bouncycastle
// Armor checksum is optional.
- (void)testIssue93OptionalChecksum {
    let keys1 = [PGPTestUtils readKeysFromPath:@"issue93-keys1.asc"];
    XCTAssertEqual(keys1.count, (NSUInteger)1);
    let keys2 = [PGPTestUtils readKeysFromPath:@"issue93-keys2.asc"];
    XCTAssertEqual(keys2.count, (NSUInteger)1);
}

- (void)testSigningSubKey {
    // subkey generated with GnuPG 2.1.18
    //
    // gpg --gen-key
    //      Test User <test@fake.workingcopyapp.com>
    //      passphrase: 12345678
    // gpg --edit-key test@fake.workingcopyapp.com
    //       addkey
    //       4: RSA (sign only)
    //       50 days expiration
    // gpg --list-signatures     # to get fingerprint
    // gpg --armor --export-secret-subkeys FA0D04B6D62865E5
    
    let keys = [PGPTestUtils readKeysFromPath:@"sub-signing-key.asc"];
    XCTAssertEqual(keys.count, (NSUInteger)1);
    
    NSError* error = nil;
    let data = [@"Hello World!" dataUsingEncoding:NSUTF8StringEncoding];
    let signature = [ObjectivePGP sign:data detached:NO usingKeys:keys passphraseForKey:^NSString * _Nullable(PGPKey *k) { return @"12345678"; } error:&error];
    XCTAssertNotNil(signature, @"Signing failed: %@", error);
}

- (void)testVerificationCase1 {
    let keys = [PGPTestUtils readKeysFromPath:@"verification-test1-keys.asc"];
    let signaturePath = [PGPTestUtils pathToBundledFile:@"verification-test1-signature.asc"];
    let signatureData = [NSData dataWithContentsOfFile:signaturePath];

    NSError* error = nil;
    BOOL verified = [ObjectivePGP verifySignature:signatureData usingKeys:keys passphraseForKey:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(verified);

}

- (void)testUserAttrributes {
    let generator = [[PGPKeyGenerator alloc] init];
    let key = [generator generateFor:@"marcin77@example.com" passphrase:@"test"];
    let user = key.publicKey.users.firstObject;

    let imagePath = [PGPTestUtils pathToBundledFile:@"jpeg.jpg"];
    user.image = [NSData dataWithContentsOfFile:imagePath];

    NSError *keyExportError;
    let exportedKey = [key export:&keyExportError];
    XCTAssertNotNil(exportedKey);
}

- (void)testSymmetricKeyEncryptedMessageMDC {
    // AES
    let messagePath = [PGPTestUtils pathToBundledFile:@"symmetric-message1.gpg"];
    let messageData = [NSData dataWithContentsOfFile:messagePath];
    NSError *decryptError = nil;

    let decrypted = [ObjectivePGP decrypt:messageData andVerifySignature:YES usingKeys:@[] passphraseForKey:^NSString * _Nullable(PGPKey * _Nullable k) { return @"1234"; } error:&decryptError];
    XCTAssertNotNil(decrypted);
    XCTAssertEqualObjects(decrypted, [@"Lorem ipsum dolor sit amet, consectetur adipiscing elit. Praesent commodo cursus magna, vel scelerisque nisl consectetur et. Cum sociis natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus." dataUsingEncoding:NSUTF8StringEncoding]);
}

- (void)testSymmetricKeyEncryptedMessageTwofish {
    // TwoFish
    let messagePath = [PGPTestUtils pathToBundledFile:@"symmetric-message2.gpg"];
    let messageData = [NSData dataWithContentsOfFile:messagePath];
    NSError *decryptError = nil;

    let decrypted = [ObjectivePGP decrypt:messageData andVerifySignature:YES usingKeys:@[] passphraseForKey:^NSString * _Nullable(PGPKey * _Nullable k) { return @"1234"; } error:&decryptError];
    XCTAssertNotNil(decrypted);
    XCTAssertEqualObjects(decrypted, [@"Lorem ipsum dolor sit amet, consectetur adipiscing elit. Praesent commodo cursus magna, vel scelerisque nisl consectetur et. Cum sociis natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus." dataUsingEncoding:NSUTF8StringEncoding]);
}

// https://github.com/krzyzanowskim/ObjectivePGP/issues/99
- (void)testIssue99OpenPGP_CFB {
    let keyring = [[PGPKeyring alloc] init];
    let pubKeys = [PGPTestUtils readKeysFromPath:@"issue99/public.asc"];
    let secKeys = [PGPTestUtils readKeysFromPath:@"issue99/private.asc"];
    [keyring importKeys:pubKeys];
    [keyring importKeys:secKeys];

    XCTAssertEqual(keyring.keys.count, (NSUInteger)1);

    let messagePath = [PGPTestUtils pathToBundledFile:@"issue99/message.asc"];
    let messageData = [NSData dataWithContentsOfFile:messagePath];
    XCTAssertNotNil(messageData);

    NSError *decryptError;
    let decryptedData = [ObjectivePGP decrypt:messageData andVerifySignature:NO usingKeys:keyring.keys passphraseForKey:^NSString * _Nullable(PGPKey * _Nullable key) {
        return @"abcd";
    } error:&decryptError];

    XCTAssertNil(decryptError);
    XCTAssertNotNil(decryptedData);

    let decryptedString = [[NSString alloc] initWithData:decryptedData encoding:NSUTF8StringEncoding];
    XCTAssertEqualObjects(decryptedString, @"Test\n-- Sent from my Android device with Secure Email.\n");
}

// PGPSymmetricallyEncryptedDataPacket
- (void)testIssue99OpenPGP_CFB_readPacketsFromData {
    let keyring = [[PGPKeyring alloc] init];
    let pubKeys = [PGPTestUtils readKeysFromPath:@"issue99-2/public.asc"];
    let secKeys = [PGPTestUtils readKeysFromPath:@"issue99-2/private.asc"];
    [keyring importKeys:pubKeys];
    [keyring importKeys:secKeys];

    XCTAssertEqual(keyring.keys.count, (NSUInteger)1);

    let messagePath = [PGPTestUtils pathToBundledFile:@"issue99-2/message.asc"];
    let messageData = [NSData dataWithContentsOfFile:messagePath];
    XCTAssertNotNil(messageData);

    NSError *decryptError;
    let decryptedData = [ObjectivePGP decrypt:messageData andVerifySignature:NO usingKeys:keyring.keys passphraseForKey:^NSString * _Nullable(PGPKey * _Nullable key) {
        return @"abcd";
    } error:&decryptError];

    XCTAssertNil(decryptError);
    XCTAssertNotNil(decryptedData);

    let decryptedString = [[NSString alloc] initWithData:decryptedData encoding:NSUTF8StringEncoding];
    XCTAssertEqualObjects(decryptedString, @"Hello\n-- Sent from my Android device with Secure Email.\n");
}

// https://github.com/krzyzanowskim/ObjectivePGP/issues/102
- (void)testMemoryUsageIssue102 {
    // Temp large file
    let tmpFilePath = @"/tmp/objectivepgp_test102";
    [[NSData data] writeToFile:tmpFilePath atomically:YES];
    let fileHandle = [NSFileHandle fileHandleForUpdatingAtPath:tmpFilePath];
    [fileHandle truncateFileAtOffset:1024 * 1024 * 30]; // 30 MB
    [fileHandle closeFile];

    let plaintextData = [NSData dataWithContentsOfURL:[NSURL fileURLWithPath:tmpFilePath]];
    NSLog(@"Size of Unencrypted Data (in MB): %@",@(plaintextData.length / 1024 / 1024));

    let generator = [[PGPKeyGenerator alloc] init];
    let key = [generator generateFor:@"test+mem@example.com" passphrase:nil];

    // encrypt data
    [ObjectivePGP encrypt:plaintextData addSignature:NO usingKeys:@[key] passphraseForKey:nil error:nil];

    // cleanup
    [NSFileManager.defaultManager removeItemAtPath:tmpFilePath error:nil];
}


@end
