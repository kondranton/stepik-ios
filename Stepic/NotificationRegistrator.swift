//
//  NotificationRegistrator.swift
//  Stepic
//
//  Created by Alexander Karpov on 21.04.16.
//  Copyright © 2016 Alex Karpov. All rights reserved.
//

import UIKit
//import Google
import FirebaseMessaging
import Firebase

//Class for registering the remote notifications service
class NotificationRegistrator: NSObject {
    static let sharedInstance = NotificationRegistrator()
    
    fileprivate override init() {
        super.init()
    }
        
    func registerForRemoteNotifications(_ application: UIApplication) {
        if StepicApplicationsInfo.shouldRegisterNotifications {
            let settings: UIUserNotificationSettings =
                UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
            application.registerUserNotificationSettings(settings)
            application.registerForRemoteNotifications()
        }
        
        if AuthInfo.shared.isAuthorized {
            if let token = FIRInstanceID.instanceID().token() {
                registerDevice(token)
            }
        }
    }
    
    func getGCMRegistrationToken(deviceToken: Data) {
        FIRInstanceID.instanceID().setAPNSToken(deviceToken, type: FIRInstanceIDAPNSTokenType.unknown)
    }
    
    var registrationOptions = [String: AnyObject]()
    
    let registrationKey = "onRegistrationCompleted"

    func registerDevice(_ registrationToken: String!) {
        print("Registration Token: \(registrationToken)")
        let device = Device(registrationId: registrationToken, deviceDescription: DeviceInfo.deviceInfoString)
        ApiDataDownloader.devices.create(device, success: {
            device in
            DeviceDefaults.sharedDefaults.deviceId = device.id
            print("created device: \(device.getJSON())")
        }, error : {
            error in 
            print("device creation error")
        })
    }    
    
    
    // Should be executed first before any actions were performed, contains abort()
    //TODO: remove abort, add failure completion handler
    func unregisterFromNotifications(completion: @escaping ((Void)->Void)) {
        print(AuthInfo.shared.token?.accessToken ?? "")
        UIApplication.shared.unregisterForRemoteNotifications()
        if let deviceId = DeviceDefaults.sharedDefaults.deviceId {
            ApiDataDownloader.devices.delete(deviceId, success: 
                {
                    print("successfully deleted device with id \(deviceId) when unregistering from notifications")
                    completion()
                }, error: {
                    error in
                    switch error {
                    case .notFound:
                        print("device not found on deletion, not writing executable task")
                        return
                    case .other(error: let e, code: _, message: let message):
                        if let errorMessage = message {
                            print(errorMessage)
                        }
                        if e != nil {
                            print("initializing delete device task")
                            print("user id \(String(describing: AuthInfo.shared.userId)) , token \(String(describing: AuthInfo.shared.token))")
                            if let userId =  AuthInfo.shared.userId,
                                let token = AuthInfo.shared.token {
                                
                                let deleteTask = DeleteDeviceExecutableTask(userId: userId, deviceId: deviceId)
                                ExecutionQueues.sharedQueues.connectionAvailableExecutionQueue.push(deleteTask)
                                
                                let userPersistencyManager = PersistentUserTokenRecoveryManager(baseName: "Users")
                                userPersistencyManager.writeStepicToken(token, userId: userId)
                                
                                let taskPersistencyManager = PersistentTaskRecoveryManager(baseName: "Tasks")
                                taskPersistencyManager.writeTask(deleteTask, name: deleteTask.id)
                                
                                let queuePersistencyManager = PersistentQueueRecoveryManager(baseName: "Queues")
                                queuePersistencyManager.writeQueue(ExecutionQueues.sharedQueues.connectionAvailableExecutionQueue, key: ExecutionQueues.sharedQueues.connectionAvailableExecutionQueueKey)
                                
                                DeviceDefaults.sharedDefaults.deviceId = nil
                                completion()
                            } else {
                                print("Could not get current user ID or token to delete device")
                                completion()
                            }
                        }
                    }
                }
            )
        } else {
            print("no deviceId found")
            completion()
        }
    }
    
}
