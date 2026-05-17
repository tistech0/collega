from pydantic import BaseModel, EmailStr, Field


class RegisterRequest(BaseModel):
    email: EmailStr
    password: str


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class RefreshRequest(BaseModel):
    refresh_token: str


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    is_beta: bool
    is_subscribed: bool


class ProfileUpdateRequest(BaseModel):
    first_name: str | None = Field(default=None, max_length=100)
    year_group: str | None = Field(default=None, max_length=50)
    faculty: str | None = Field(default=None, max_length=150)


class MeResponse(BaseModel):
    id: str
    email: str
    is_beta: bool
    is_subscribed: bool
    first_name: str | None
    year_group: str | None
    faculty: str | None
    monthly_reloads: int
    monthly_reloads_max: int
