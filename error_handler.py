"""
Error handling middleware for FastAPI
Standardizes all error responses across the API
"""

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from datetime import datetime
import uuid
from enum import Enum
from typing import Optional, Dict, Any


class ErrorCode(str, Enum):
    """Standard error codes for API responses"""
    AUTH_ERROR = "AUTH_ERROR"
    NETWORK_ERROR = "NETWORK_ERROR"
    VALIDATION_ERROR = "VALIDATION_ERROR"
    RESOURCE_NOT_FOUND = "RESOURCE_NOT_FOUND"
    DUPLICATE_RESOURCE = "DUPLICATE_RESOURCE"
    DATABASE_ERROR = "DATABASE_ERROR"
    API_ERROR = "API_ERROR"
    RATE_LIMIT = "RATE_LIMIT"
    PAYMENT_ERROR = "PAYMENT_ERROR"
    INTEGRATION_ERROR = "INTEGRATION_ERROR"
    TIMEOUT = "TIMEOUT"
    PARSE_ERROR = "PARSE_ERROR"
    UNAUTHORIZED = "UNAUTHORIZED"
    FORBIDDEN = "FORBIDDEN"
    CONFLICT = "CONFLICT"
    GONE = "GONE"
    UNSUPPORTED_MEDIA_TYPE = "UNSUPPORTED_MEDIA_TYPE"
    INTERNAL_SERVER_ERROR = "INTERNAL_SERVER_ERROR"
    SERVICE_UNAVAILABLE = "SERVICE_UNAVAILABLE"
    GATEWAY_TIMEOUT = "GATEWAY_TIMEOUT"


# HTTP status code mapping
HTTP_STATUS_CODES = {
    ErrorCode.AUTH_ERROR: 401,
    ErrorCode.UNAUTHORIZED: 401,
    ErrorCode.FORBIDDEN: 403,
    ErrorCode.RESOURCE_NOT_FOUND: 404,
    ErrorCode.DUPLICATE_RESOURCE: 409,
    ErrorCode.CONFLICT: 409,
    ErrorCode.VALIDATION_ERROR: 422,
    ErrorCode.UNSUPPORTED_MEDIA_TYPE: 415,
    ErrorCode.RATE_LIMIT: 429,
    ErrorCode.TIMEOUT: 504,
    ErrorCode.PAYMENT_ERROR: 402,
    ErrorCode.PARSE_ERROR: 400,
    ErrorCode.GONE: 410,
    ErrorCode.NETWORK_ERROR: 502,
    ErrorCode.GATEWAY_TIMEOUT: 504,
    ErrorCode.API_ERROR: 500,
    ErrorCode.DATABASE_ERROR: 500,
    ErrorCode.INTEGRATION_ERROR: 502,
    ErrorCode.INTERNAL_SERVER_ERROR: 500,
    ErrorCode.SERVICE_UNAVAILABLE: 503,
}

# User-friendly messages (never expose stack traces)
USER_FRIENDLY_MESSAGES = {
    ErrorCode.AUTH_ERROR: "Authentication failed. Please check your credentials.",
    ErrorCode.UNAUTHORIZED: "You are not authorized to access this resource.",
    ErrorCode.FORBIDDEN: "Access denied.",
    ErrorCode.RESOURCE_NOT_FOUND: "The requested resource was not found.",
    ErrorCode.DUPLICATE_RESOURCE: "This resource already exists.",
    ErrorCode.DATABASE_ERROR: "Database operation failed. Please try again.",
    ErrorCode.VALIDATION_ERROR: "The provided data is invalid.",
    ErrorCode.API_ERROR: "An API error occurred. Please try again.",
    ErrorCode.RATE_LIMIT: "Too many requests. Please try again later.",
    ErrorCode.TIMEOUT: "The request timed out. Please try again.",
    ErrorCode.PAYMENT_ERROR: "Payment processing failed.",
    ErrorCode.INTEGRATION_ERROR: "Integration service error. Please try again.",
    ErrorCode.NETWORK_ERROR: "Network error. Please check your connection.",
    ErrorCode.PARSE_ERROR: "Unable to parse the request.",
    ErrorCode.GONE: "The requested resource is no longer available.",
    ErrorCode.UNSUPPORTED_MEDIA_TYPE: "Unsupported media type.",
    ErrorCode.INTERNAL_SERVER_ERROR: "Internal server error. Please try again.",
    ErrorCode.SERVICE_UNAVAILABLE: "Service temporarily unavailable. Please try again later.",
    ErrorCode.GATEWAY_TIMEOUT: "Gateway timeout. Please try again.",
    ErrorCode.CONFLICT: "Conflict with existing data.",
}


class AppError(Exception):
    """Standardized error class for all application errors"""
    
    def __init__(
        self,
        code: ErrorCode,
        message: str,
        status_code: Optional[int] = None,
        details: Optional[Dict[str, Any]] = None
    ):
        self.code = code
        self.message = message
        self.status_code = status_code or HTTP_STATUS_CODES.get(code, 500)
        self.details = details or {}
        self.error_id = str(uuid.uuid4()).replace('-', '')[:12]
        self.timestamp = datetime.utcnow().isoformat() + 'Z'
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert error to response dictionary"""
        return {
            "code": self.code,
            "message": self.message,
            "timestamp": self.timestamp,
            "errorId": self.error_id,
            "details": self.details,
        }
    
    def to_response(self) -> JSONResponse:
        """Convert error to JSONResponse"""
        return JSONResponse(
            status_code=self.status_code,
            content={
                "success": False,
                "error": self.to_dict(),
            },
        )


def sanitize_error_message(error: Exception) -> str:
    """Convert internal errors to user-safe messages"""
    error_str = str(error).lower()
    
    if "database" in error_str or "db" in error_str:
        return USER_FRIENDLY_MESSAGES[ErrorCode.DATABASE_ERROR]
    if "connection" in error_str or "timeout" in error_str:
        return USER_FRIENDLY_MESSAGES[ErrorCode.NETWORK_ERROR]
    if "auth" in error_str or "credential" in error_str:
        return USER_FRIENDLY_MESSAGES[ErrorCode.AUTH_ERROR]
    if "not found" in error_str:
        return USER_FRIENDLY_MESSAGES[ErrorCode.RESOURCE_NOT_FOUND]
    if "duplicate" in error_str or "conflict" in error_str:
        return USER_FRIENDLY_MESSAGES[ErrorCode.DUPLICATE_RESOURCE]
    if "validation" in error_str:
        return USER_FRIENDLY_MESSAGES[ErrorCode.VALIDATION_ERROR]
    
    return USER_FRIENDLY_MESSAGES[ErrorCode.INTERNAL_SERVER_ERROR]


def create_error_response(
    code: ErrorCode,
    message: str,
    status_code: Optional[int] = None,
    details: Optional[Dict[str, Any]] = None
) -> JSONResponse:
    """Factory function to create standardized error responses"""
    error = AppError(code, message, status_code, details)
    return error.to_response()


async def global_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    """
    Global exception handler for all unhandled exceptions
    Converts any exception to standardized AppError response
    """
    
    # If already an AppError, just return its response
    if isinstance(exc, AppError):
        return exc.to_response()
    
    # Map common exceptions to AppError
    error_message = str(exc)
    
    if isinstance(exc, ValueError):
        return AppError(
            ErrorCode.VALIDATION_ERROR,
            sanitize_error_message(exc),
            details={"originalError": error_message}
        ).to_response()
    
    if isinstance(exc, KeyError):
        return AppError(
            ErrorCode.RESOURCE_NOT_FOUND,
            USER_FRIENDLY_MESSAGES[ErrorCode.RESOURCE_NOT_FOUND],
            details={"key": str(exc)}
        ).to_response()
    
    if isinstance(exc, TimeoutError):
        return AppError(
            ErrorCode.TIMEOUT,
            USER_FRIENDLY_MESSAGES[ErrorCode.TIMEOUT],
        ).to_response()
    
    if isinstance(exc, PermissionError):
        return AppError(
            ErrorCode.UNAUTHORIZED,
            USER_FRIENDLY_MESSAGES[ErrorCode.UNAUTHORIZED],
        ).to_response()
    
    if isinstance(exc, ConnectionError):
        return AppError(
            ErrorCode.NETWORK_ERROR,
            USER_FRIENDLY_MESSAGES[ErrorCode.NETWORK_ERROR],
        ).to_response()
    
    # Default: internal server error
    return AppError(
        ErrorCode.INTERNAL_SERVER_ERROR,
        USER_FRIENDLY_MESSAGES[ErrorCode.INTERNAL_SERVER_ERROR],
        details={"exceptionType": type(exc).__name__}
    ).to_response()


def register_error_handlers(app: FastAPI) -> None:
    """Register error handlers with the FastAPI app"""
    app.add_exception_handler(Exception, global_exception_handler)
