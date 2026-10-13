//
//  AttendanceViewController.swift
//  MODEmployee
//
//  Created by Rajpal singh on 12/10/26.
//

import UIKit
import Combine

class AttendanceViewController: UIViewController {
    
    // MARK: - Properties
    
    private let viewModel = AttendanceViewModel()
    
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }()
    
    private let contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let headerView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBlue
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let employeeNameLabel: UILabel = {
        let label = UILabel()
        label.text = "Employee Name"
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let employeeIdLabel: UILabel = {
        let label = UILabel()
        label.text = "ID: EMP001"
        label.font = .systemFont(ofSize: 14)
        label.textColor = .white.withAlphaComponent(0.8)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let siteNameLabel: UILabel = {
        let label = UILabel()
        label.text = "Site: Main Office"
        label.font = .systemFont(ofSize: 14)
        label.textColor = .white.withAlphaComponent(0.8)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let locationCard: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 12
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.1
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 4
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let locationTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Location Status"
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let locationStatusLabel: UILabel = {
        let label = UILabel()
        label.text = "Checking location..."
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let locationIconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "location.fill")
        imageView.tintColor = .systemBlue
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let attendanceButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Mark Attendance", for: .normal)
        button.backgroundColor = .systemGreen
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        button.layer.cornerRadius = 12
        button.isEnabled = false
        button.alpha = 0.5
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let statusLabel: UILabel = {
        let label = UILabel()
        label.text = ""
        label.font = .systemFont(ofSize: 14)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let retryButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Retry", for: .normal)
        button.setTitleColor(.systemBlue, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        button.isHidden = true
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupBindings()
        
        // Start location check
        Task {
            await viewModel.startAttendanceFlow()
        }
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = .systemGroupedBackground
        title = "Attendance"
        
        // Add logout button to navigation bar
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Logout",
            style: .plain,
            target: self,
            action: #selector(logoutButtonTapped)
        )
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(headerView)
        headerView.addSubview(employeeNameLabel)
        headerView.addSubview(employeeIdLabel)
        headerView.addSubview(siteNameLabel)
        contentView.addSubview(locationCard)
        locationCard.addSubview(locationTitleLabel)
        locationCard.addSubview(locationStatusLabel)
        locationCard.addSubview(locationIconImageView)
        contentView.addSubview(attendanceButton)
        contentView.addSubview(statusLabel)
        contentView.addSubview(retryButton)
        contentView.addSubview(activityIndicator)
        
        NSLayoutConstraint.activate([
            // ScrollView
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // ContentView
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // Header
            headerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 120),
            
            // Employee Name
            employeeNameLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 20),
            employeeNameLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            employeeNameLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            
            // Employee ID
            employeeIdLabel.topAnchor.constraint(equalTo: employeeNameLabel.bottomAnchor, constant: 8),
            employeeIdLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            
            // Site Name
            siteNameLabel.topAnchor.constraint(equalTo: employeeIdLabel.bottomAnchor, constant: 4),
            siteNameLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            
            // Location Card
            locationCard.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 20),
            locationCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            locationCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            locationCard.heightAnchor.constraint(greaterThanOrEqualToConstant: 80),
            
            // Location Title
            locationTitleLabel.topAnchor.constraint(equalTo: locationCard.topAnchor, constant: 16),
            locationTitleLabel.leadingAnchor.constraint(equalTo: locationCard.leadingAnchor, constant: 16),
            
            // Location Icon
            locationIconImageView.topAnchor.constraint(equalTo: locationTitleLabel.bottomAnchor, constant: 12),
            locationIconImageView.leadingAnchor.constraint(equalTo: locationCard.leadingAnchor, constant: 16),
            locationIconImageView.widthAnchor.constraint(equalToConstant: 24),
            locationIconImageView.heightAnchor.constraint(equalToConstant: 24),
            
            // Location Status
            locationStatusLabel.topAnchor.constraint(equalTo: locationTitleLabel.bottomAnchor, constant: 12),
            locationStatusLabel.leadingAnchor.constraint(equalTo: locationIconImageView.trailingAnchor, constant: 12),
            locationStatusLabel.trailingAnchor.constraint(equalTo: locationCard.trailingAnchor, constant: -16),
            locationStatusLabel.bottomAnchor.constraint(equalTo: locationCard.bottomAnchor, constant: -16),
            
            // Attendance Button
            attendanceButton.topAnchor.constraint(equalTo: locationCard.bottomAnchor, constant: 32),
            attendanceButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            attendanceButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            attendanceButton.heightAnchor.constraint(equalToConstant: 56),
            
            // Status Label
            statusLabel.topAnchor.constraint(equalTo: attendanceButton.bottomAnchor, constant: 16),
            statusLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Retry Button
            retryButton.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 16),
            retryButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            retryButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24),
            
            // Activity Indicator
            activityIndicator.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
        
        attendanceButton.addTarget(self, action: #selector(attendanceButtonTapped), for: .touchUpInside)
        retryButton.addTarget(self, action: #selector(retryButtonTapped), for: .touchUpInside)
    }
    
    private func setupBindings() {
        viewModel.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.updateUI(for: state)
            }
            .store(in: &cancellables)
        
        viewModel.$locationStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.locationStatusLabel.text = status
            }
            .store(in: &cancellables)
        
        viewModel.$employeeName
            .receive(on: DispatchQueue.main)
            .sink { [weak self] name in
                self?.employeeNameLabel.text = name
            }
            .store(in: &cancellables)
        
        viewModel.$employeeId
            .receive(on: DispatchQueue.main)
            .sink { [weak self] id in
                self?.employeeIdLabel.text = "ID: \(id)"
            }
            .store(in: &cancellables)
        
        viewModel.$siteName
            .receive(on: DispatchQueue.main)
            .sink { [weak self] site in
                self?.siteNameLabel.text = "Site: \(site)"
            }
            .store(in: &cancellables)
    }
    
    private func updateUI(for state: AttendanceState) {
        attendanceButton.isEnabled = viewModel.canSubmitAttendance
        attendanceButton.alpha = viewModel.canSubmitAttendance ? 1.0 : 0.5
        
        retryButton.isHidden = !viewModel.canRetry
        
        if viewModel.isLoading {
            activityIndicator.startAnimating()
            attendanceButton.isHidden = true
        } else {
            activityIndicator.stopAnimating()
            attendanceButton.isHidden = false
        }
        
        switch state {
        case .unauthenticated:
            statusLabel.text = "Please login"
            statusLabel.textColor = .systemRed
            navigateToLogin()
            
        case .checkingLocation:
            statusLabel.text = "Checking location..."
            statusLabel.textColor = .systemOrange
            locationIconImageView.image = UIImage(systemName: "location.fill")
            locationIconImageView.tintColor = .systemOrange
            
        case .outsideGeofence(let reason):
            statusLabel.text = reason
            statusLabel.textColor = .systemRed
            locationIconImageView.image = UIImage(systemName: "location.slash.fill")
            locationIconImageView.tintColor = .systemRed
            
        case .readyForAttendance:
            statusLabel.text = "Ready to mark attendance"
            statusLabel.textColor = .systemGreen
            locationIconImageView.image = UIImage(systemName: "checkmark.circle.fill")
            locationIconImageView.tintColor = .systemGreen
            
        case .creatingVerificationSession:
            statusLabel.text = "Creating verification session..."
            statusLabel.textColor = .systemBlue
            
        case .startingLiveness:
            statusLabel.text = "Starting liveness detection..."
            statusLabel.textColor = .systemBlue
            
        case .livenessInProgress:
            statusLabel.text = "Liveness detection in progress..."
            statusLabel.textColor = .systemBlue
            
        case .livenessFailed(let reason):
            statusLabel.text = reason
            statusLabel.textColor = .systemRed
            
        case .submittingVerification:
            statusLabel.text = "Submitting verification..."
            statusLabel.textColor = .systemBlue
            
        case .attendanceSuccess(let timestamp):
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            statusLabel.text = "Attendance marked at \(formatter.string(from: timestamp))"
            statusLabel.textColor = .systemGreen
            attendanceButton.setTitle("Completed", for: .normal)
            attendanceButton.isEnabled = false
            
        case .recoverableError(let message):
            statusLabel.text = message
            statusLabel.textColor = .systemRed
        }
    }
    
    // MARK: - Actions
    
    @objc private func attendanceButtonTapped() {
        Task {
            print("Attendence Butto Tapped")
            await viewModel.submitAttendance(presenter: self)
        }
    }
    
    @objc private func retryButtonTapped() {
        Task {
            await viewModel.retry()
        }
    }
    
    @objc private func logoutButtonTapped() {
        let alert = UIAlertController(
            title: "Logout",
            message: "Are you sure you want to logout?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Logout", style: .destructive) { [weak self] _ in
            self?.viewModel.logout()
            self?.navigateToLogin()
        })
        
        present(alert, animated: true)
    }
    
    // MARK: - Navigation
    
    private func navigateToLogin() {
        let loginVC = LoginViewController()
        navigationController?.setViewControllers([loginVC], animated: true)
    }
    
    // MARK: - Combine Cancellables
    
    private var cancellables = Set<AnyCancellable>()
}
