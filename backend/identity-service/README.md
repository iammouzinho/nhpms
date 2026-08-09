# NHPMS Identity Service

Spring Boot 3.5 / Java 21 authentication service for the National Healthcare Patient Management System.

## Features in this MVP

- Username/password authentication
- Argon2 password hashing
- JWT access tokens
- Rotating refresh tokens
- Logout/revocation
- Role claims
- Facility access claims
- Failed-login lockout
- PostgreSQL persistence
- Flyway migrations
- Health endpoint
- Docker Compose

## Run locally

Requirements: Java 21, Maven 3.9+, PostgreSQL 16.

```bash
mvn clean test
mvn spring-boot:run
```

Set `JWT_SECRET` to a random value of at least 32 characters. For production use a much longer secret managed by a secret manager.

## Run with Docker

```bash
mvn clean package -DskipTests
docker compose up --build
```

## API

### Login

`POST /api/v1/auth/login`

```json
{
  "username": "admin",
  "password": "password"
}
```

### Refresh

`POST /api/v1/auth/refresh`

```json
{"refreshToken":"..."}
```

### Logout

`POST /api/v1/auth/logout`

```json
{"refreshToken":"..."}
```

### Current user

`GET /api/v1/auth/me`

Header:
`Authorization: Bearer <access-token>`

### Create user

`POST /api/v1/admin/users`

Requires `ROLE_NATIONAL_ADMIN`.

## Database

The migration creates only the IAM objects needed by this service. The larger NHPMS database script can be used when deploying the complete platform. If using the existing shared NHPMS database, configure Flyway baseline appropriately or migrate the IAM tables into the service's migration history.

## Security notes

1. Never commit production secrets.
2. Use TLS everywhere.
3. Replace the development JWT secret with a managed secret.
4. Prefer asymmetric RS256/ES256 keys when the API gateway and multiple services are deployed.
5. Refresh tokens are stored only as SHA-256 hashes.
6. Do not put passwords, biometric templates, or medical information in JWT claims.
7. Facility isolation must also be enforced by downstream services/database RLS; JWT facility claims alone are not sufficient.
