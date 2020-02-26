//
//  AddServerModel.swift
//  iWontPayAnyway
//
//  Created by Camille Mainz on 05.02.20.
//  Copyright © 2020 Mayflower GmbH. All rights reserved.
//

import Foundation
import UIKit
import Combine

class AddProjectModel: ObservableObject {
    
    
    @Published
    var projectType = ProjectBackend.cospend
    
    @Published
    var serverAddress = ""
    
    @Published
    var projectName = ""
    
    @Published
    var projectPassword = ""
    
    static let shared = AddProjectModel()
    
    private init() {
        
    }
    
    func reset() {
        self.serverAddress = ""
        self.projectName = ""
        self.projectPassword = ""
    }
    
    var validatedAddress: AnyPublisher<(ProjectBackend, String?), Never> {
        return Publishers.CombineLatest($projectType, $serverAddress)
            .map {
                type, serverAddress in
                if type == .cospend {
                    return (type, serverAddress)
                } else {
                    return (type, nil)
                }
        }
        .eraseToAnyPublisher()
    }
    
    var validatedInput: AnyPublisher<Project, Never> {
        return Publishers.CombineLatest3(validatedAddress, $projectName, $projectPassword)
            .debounce(for: 0.5, scheduler: DispatchQueue.main)
            .compactMap { server, name, password in
                if let address = server.1, address.isValidURL && !name.isEmpty && !password.isEmpty {
                    guard let url = URL(string: address) else { return nil }
                    return Project(name: name, password: password, backend: server.0, url: url)
                } else {
                    return nil
                }
            }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var validatedServer: AnyPublisher<Bool, Never> {
        return Publishers.FlatMap(upstream: validatedInput, maxPublishers: .unlimited) {
            project in
            return NetworkService.shared.testProject(project)
        }
        .receive(on: RunLoop.main)
        .eraseToAnyPublisher()
    }
    
    var connectionInProgress: AnyPublisher<(Project,Bool), Never> {
        return Publishers.CombineLatest(validatedInput, validatedServer)
        .map {
                input, server in
            (input, !server)
            }
        .eraseToAnyPublisher()
    }
}
