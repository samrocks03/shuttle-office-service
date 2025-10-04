# Shuttle Office Service

A robust API-based system for managing corporate shuttle services, designed to streamline employee transportation.

## Overview

Shuttle Office Service is a Ruby on Rails API application that helps companies manage their shuttle bus services for employees. The system allows for bus scheduling, seat reservation, and comprehensive management of company transportation resources.

## Features

- **User Authentication & Authorization**
  - JWT-based secure authentication
  - Role-based access control (Admin and Employee roles)
  - Secure password handling with BCrypt

- **Company Management**
  - Create and manage multiple companies
  - Associate buses and employees with specific companies

- **Bus Fleet Management**
  - Track bus details (number, capacity, model)
  - Associate buses with companies

- **Schedule Management**
  - Create and manage bus schedules with start points
  - Set arrival and departure times
  - Automatically track available seats
  - Validation for overlapping schedules

- **Reservation System**
  - Allow employees to book seats on scheduled buses
  - Automatic seat management (decrement/increment)
  - PDF generation for reservation confirmations
  - Prevent double-booking

- **Advanced Search & Filtering**
  - Search functionality across all resources
  - Pagination for handling large datasets
  - Customizable sorting options

## Tech Stack

- **Framework**: Ruby on Rails 7.0.8 (API mode)
- **Ruby Version**: 3.2.2
- **Database**: PostgreSQL
- **Authentication**: JWT (JSON Web Tokens)
- **Authorization**: CanCanCan
- **Pagination**: Pagy
- **PDF Generation**: Prawn
- **Serialization**: Active Model Serializers
- **API Documentation**: Raddocs/RSpec API Documentation
- **Testing**: RSpec, FactoryBot, Shoulda Matchers
- **Code Quality**: SimpleCov, Bullet

## API Endpoints

### Authentication
- `POST /login` - User login (returns JWT token)

### Users
- `GET /users` - List all users (admin only)
- `GET /users/:id` - Show user details
- `POST /users` - Create new user
- `PATCH/PUT /users/:id` - Update user
- `DELETE /users/:id` - Delete user (admin only)

### Companies
- `GET /companies` - List all companies
- `POST /companies` - Create new company (admin only)
- `PATCH/PUT /companies/:id` - Update company (admin only)
- `DELETE /companies/:id` - Delete company (admin only)

### Buses
- `GET /buses` - List all buses
- `POST /buses` - Create new bus (admin only)
- `PATCH/PUT /buses/:id` - Update bus (admin only)
- `DELETE /buses/:id` - Delete bus (admin only)

### Schedules
- `GET /schedules` - List all schedules
- `GET /buses/:bus_id/schedules` - List schedules for specific bus
- `POST /buses/:bus_id/schedules` - Create new schedule (admin only)
- `PATCH/PUT /schedules/:id` - Update schedule (admin only)
- `DELETE /schedules/:id` - Delete schedule (admin only)

### Reservations
- `GET /reservations` - List all reservations
- `GET /reservations/:id` - Show reservation details
- `POST /reservations` - Create new reservation
- `DELETE /reservations/:id` - Delete reservation (admin only)

## Setup and Installation

### Prerequisites
- Ruby 3.2.2
- PostgreSQL
- Docker (optional)

### Local Setup
1. Clone the repository
   ```bash
   git clone https://github.com/yourusername/shuttle-office-service.git
   cd shuttle-office-service
   ```

2. Install dependencies
   ```bash
   bundle install
   ```

3. Database setup
   ```bash
   rails db:create db:migrate db:seed
   ```

4. Start the server
   ```bash
   rails server
   ```

### Docker Setup
1. Build and start the containers
   ```bash
   docker-compose up --build
   ```

2. Setup the database
   ```bash
   docker-compose exec web rails db:create db:migrate db:seed
   ```

## Running Tests
```bash
bundle exec rspec
```

## License
This project is licensed under the MIT License.

## Contributing
Contributions are welcome! Please feel free to submit a Pull Request.