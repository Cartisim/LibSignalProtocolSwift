//
//  SignalProtocolStoreContext.swift
//  libsignal-protocol-swift
//
//  Created by User on 01.11.17.
//  Copyright © 2017 User. All rights reserved.
//

import Foundation


/**
 Provide all storage delegates when creating a new `SignalInterface`.
 Classes implementing this protocol can use `SignalInterface.init(keyStore:)`.
 It is also possible to provide each delegate separately.
 */
public protocol SignalProtocolStoreContext {

    /// The Identity Key store that stores the records for the identity key module
    var identityKeyStore: IdentityKeyStoreDelegate { get }

    /// The Pre Key store that stores the records for the pre key module
    var preKeyStore: PreKeyStoreDelegate { get }

    /// The Sender Key store that stores the records for the sender key module
    var senderKeyStore: SenderKeyStoreDelegate { get }

    /// The Session store that stores the records for the session module
    var sessionStore: SessionStoreDelegate { get }

    /// The Signed Pre Key store that stores the records for the signed pre key module
    var signedPreKeyStore: SignedPreKeyStoreDelegate { get }

}


extension SignalProtocolStoreContext {

    /**
     Return the identity key pair. This key should be generated once at
     install time by calling `KeyStore.generateIdentityKeyPair()`.
     - returns: The identity key pair
     - throws: `SignalError.storageError`
     */
    public func getIdentityKey() throws -> KeyPair {
        guard let key = identityKeyStore.identityKey else {
            throw SignalError(.storageError, "Could not get identity key from store")
        }
        return key
    }

    /**
     Return the local registration id. This id should be generated once at
     install time by calling `KeyStore.generateRegistrationID()`.
     - returns: The local registration id
     - throws: `SignalError.storageError`
     */
    public func getLocalRegistrationID() throws -> UInt32 {
        guard let id =  identityKeyStore.localRegistrationID else {
            throw SignalError(.storageError, "Could not get local registration id from store")
        }
        return id
    }

    /**
     Determine whether a remote client's identity is trusted. The convention is
     that the TextSecure protocol is 'trust on first use.'  This means that an
     identity key is considered 'trusted' if there is no entry for the recipient in
     the local store, or if it matches the saved key for a recipient in the local store.
     Only if it mismatches an entry in the local store is it considered 'untrusted.'

     - parameter identity: The identity key to verify
     - parameter address: The address of the remote client
     - returns: `true` if trusted, `false` if not trusted
     */
    public func isTrusted(identity: PublicKey, for address: SignalAddress) -> Bool {
        return identityKeyStore.isTrusted(identity: identity.data, for: address)
    }

    /**
     Store a remote client's identity key as trusted. The value of key_data may be null.
     In this case remove the key data from the identity store, but retain any metadata
     that may be kept alongside it.

     - parameter identity: The identity public key (may be null)
     - parameter address: The address of the remote client
     - returns: `true` on success
     */
    public func save(identity: PublicKey?, for address: SignalAddress) throws {
        guard identityKeyStore.save(identity: identity?.data, for: address) else {
            throw SignalError(.storageError, "Could not save identity for \(address)")
        }
    }
}

extension SignalProtocolStoreContext {

    /**
     Provide a Pre Key for a given id.

     - parameter id: The pre key ID
     - returns: The pre key
     - throws: `SignalError.invalidKeyID`, `SignalError.storageError`
     */
    public func preKey(for id: UInt32) throws -> SessionPreKey {
        guard let key = preKeyStore.preKey(for: id) else {
            throw SignalError(.invalidId, "No PreKey for id \(id)")
        }
        return try SessionPreKey(from: key)
    }

    /**
     Store a pre key for a given id.

     - parameter preKey: The key to store
     - throws: `SignalErrorType.storageError`, `SignalErrorType.invalidProtoBuf`
     */
    public func store(preKey: SessionPreKey) throws {
        guard let data = try? preKey.data() else {
            throw SignalError(.invalidProtoBuf, "Could not serialize PreKey \(preKey.id)")
        }
        guard preKeyStore.store(preKey: data, for: preKey.id) else {
            throw SignalError(.storageError, "Could not store PreKey \(preKey.id)")
        }
    }

    /**
     Indicate if a pre key exists for an id.

     - parameter id: The pre key id
     - returns: `true` if a key exists
     */
    public func containsPreKey(for id: UInt32) -> Bool {
        return preKeyStore.containsPreKey(for: id)
    }

    /**
     Remove a pre key.

     - parameter id: The pre key id.
     - throws: `SignalError.storageError`
     */
    public func removePreKey(for id: UInt32) throws {
        guard preKeyStore.removePreKey(for: id) else {
            throw SignalError(.storageError, "Could not delete PreKey \(id)")
        }
    }

    var lastPreKeyId: UInt32 {
        return preKeyStore.lastId
    }
}

extension SignalProtocolStoreContext {

    /**
     Returns a copy of the sender key record corresponding to the (groupId + senderId + deviceId) tuple.

     - parameter senderKeyName: The address and group of the remote client
     - returns: The Sender Key, or nil if no key exists
     - throws: `SignalErrorType.invalidProtoBuf`
     */
    func loadSenderKey(for senderKeyName: SignalSenderKeyName) throws -> SenderKeyRecord? {
        guard let senderKey = senderKeyStore.loadSenderKey(senderKeyName: senderKeyName) else {
            return nil
        }
        return try SenderKeyRecord(from: senderKey)
    }

    /**
     Stores a copy of the sender key record corresponding to the (groupId + senderId + deviceId) tuple.

     - parameter senderKey: The key to store
     - parameter senderKeyName: The address and group of the remote client
     - throws: `SignalErrorType.storageError`, `SignalErrorType.invalidProtoBuf`
     */
    func store(senderKey: SenderKeyRecord, for senderKeyName: SignalSenderKeyName) throws {
        guard let data = try? senderKey.data() else {
            throw SignalError(.invalidProtoBuf, "Could not serialize record for \(senderKeyName)")
        }
        guard senderKeyStore.store(senderKey: data, for: senderKeyName) else {
            throw SignalError(.storageError, "Could not store record for \(senderKeyName)")
        }
    }
}

extension SignalProtocolStoreContext {

    /**
     Load a session for a given address.

     - parameter address: The address of the remote client
     - returns: The loaded session record, or a new one if no session exists for the address
     - throws: `SignalError.storageError` for an invalid record
     */
    func loadSession(for address: SignalAddress) throws -> SessionRecord {
        guard let record = sessionStore.loadSession(for: address) else {
                signalLog(level: .info, "Created new session for address \(address)")
                return SessionRecord(state: nil)
        }
        return try SessionRecord(from: record)
    }

    /**
     Retreive the recipient IDs of all active sessions for a remote client.

     - parameter recipientID: The name of the remote client.
     - returns: An array of recipient IDs
     */
    public func subDeviceSessions(for recipientID: String) -> [UInt32] {
        return sessionStore.subDeviceSessions(for: recipientID)
    }

    /**
     Store a session record for a remote client.

     - parameter session: The session record to store
     - parameter address: The address of the remote client
     - throws: `SignalError.storageError`
     */
    func store(session: SessionRecord, for address: SignalAddress) throws {
        guard let data = try? session.data() else {
            throw SignalError(.invalidProtoBuf, "Could not serialize record for \(address)")
        }
        guard sessionStore.store(session: data, for: address) else {
            throw SignalError(.storageError, "Could not store record for \(address)")
        }
    }

    /**
     Indicate if a record exists for the client address

     - parameter address: The address of the remote client
     - returns: `true` if a record exists
     */
    public func containsSession(for address: SignalAddress) -> Bool {
        return sessionStore.containsSession(for: address)
    }

    /**
     Delete a session for a remote client.

     - parameter address: The address of the remote client
     - throws: `SignalError.storageError`
     */
    func deleteSession(for address: SignalAddress) throws {
        guard sessionStore.deleteSession(for: address) else {
            throw SignalError(.storageError, "Could not delete session for \(address)")
        }
    }

    /**
     Delete all session records for a given client.

     - parameter recipientID: The name of the remote client
     - returns: The number of deleted records
     */
    func deleteAllSessions(for recipientID: String) -> Int {
        return sessionStore.deleteAllSessions(for: recipientID)
    }
}

extension SignalProtocolStoreContext {

    /**
     Provide a Signed Pre Key for a given id.

     - parameter id: The Signed Pre Key ID
     - returns: The Signed Pre Key
     - throws: `SignalError.storageError`
     */
    public func signedPreKey(for id: UInt32) throws -> SessionSignedPreKey {
        guard let record = signedPreKeyStore.signedPreKey(for: id) else {
            throw SignalError(.storageError, "No SignedPreKey \(id)")
        }
        return try SessionSignedPreKey(from: record)
    }

    /**
     Store a Signed Pre Key for a given id.

     - parameter signedPreKey: The Signed Pre Key to store
     - throws: `SignalError.storageError`
     */
    public func store(signedPreKey: SessionSignedPreKey) throws {
        guard let data = try? signedPreKey.data() else {
            throw SignalError(.invalidProtoBuf, "Could not serialize SignedPreKey \(signedPreKey.id)")
        }
        guard signedPreKeyStore.store(signedPreKey: data, for: signedPreKey.id) else {
            throw SignalError(.storageError, "Could not store SignedPreKey \(signedPreKey.id)")
        }
    }

    /**
     Indicate if a Signed Pre Key exists for an id.

     - parameter id: The Signed Pre Key id
     - returns: `true` if a key exists
     */
    public func containsSignedPreKey(for id: UInt32) -> Bool {
        return signedPreKeyStore.containsSignedPreKey(for: id)
    }

    /**
     Remove a Signed Pre Key.

     - parameter id: The Signed Pre Key id.
     - throws: `SignalError.storageError`
     */
    public func removeSignedPreKey(for id: UInt32) throws {
        guard signedPreKeyStore.removeSignedPreKey(for: id) else {
            throw SignalError(.storageError, "Could not remove SignedPreKey \(id)")
        }
    }

    /**
     Get all Ids for the SignedPreKeys in the store.
     - returns: An array of all ids for which a key is stored
     */
    public func allSignedPreKeyIds() -> [UInt32] {
        return signedPreKeyStore.allIds()
    }

    /**
     The id of the last SignedPreKey that was stored.
     */
    public var lastSignedPreKeyId: UInt32 {
        return signedPreKeyStore.lastId
    }
}
