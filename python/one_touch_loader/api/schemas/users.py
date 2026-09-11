from typing import Annotated, Literal
from pydantic import AfterValidator, BaseModel, ConfigDict, EmailStr, Field, StringConstraints

Name = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=100)]
Username = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=50)]


def validate_password_characters(value: str) -> str:
    # 영문 대·소문자와 숫자가 모두 필요해요. 특수문자는 필수가 아니며 원문을 바꾸지 않아요.
    if not (any("A" <= char <= "Z" for char in value)
            and any("a" <= char <= "z" for char in value)
            and any("0" <= char <= "9" for char in value)):
        raise ValueError("Password must include an uppercase English letter, a lowercase English letter, and a digit")
    return value


# 가입·재설정·비밀번호 로그인에서 같은 조건을 사용해요.
Password = Annotated[str, StringConstraints(min_length=8, max_length=128), AfterValidator(validate_password_characters)]


class UserProfileBody(BaseModel):
    username: Username
    first_name: Name
    last_name: Name


class EmailCodeBody(BaseModel):
    email: EmailStr
    purpose: Literal["signup", "password_reset", "username_recovery"] = "signup"


class CodeBody(BaseModel):
    challenge_id: str = Field(min_length=40, max_length=100)
    code: str = Field(pattern=r"^[0-9]{6}$")


class RegisterEmailBody(UserProfileBody, CodeBody):
    password: Password


class PasswordLoginBody(BaseModel):
    username: Username
    password: Password


class ResetPasswordBody(CodeBody):
    password: Password


class EmailChangeRequestBody(BaseModel):
    email: EmailStr
    password: Password


class EmailChangeConfirmBody(BaseModel):
    password: Password
    current_email: CodeBody
    new_email: CodeBody


class GoogleLoginBody(BaseModel):
    id_token: str = Field(min_length=1, max_length=10000)


class AppleLoginBody(BaseModel):
    code: str = Field(min_length=1, max_length=10000)
    client_id: str = Field(min_length=1, max_length=255)
    nonce: str = Field(min_length=16, max_length=255)


class KakaoLoginBody(BaseModel):
    access_token: str = Field(min_length=1, max_length=10000)


class DeleteAccountBody(BaseModel):
    model_config = ConfigDict(extra="forbid")
    apple: AppleLoginBody | None = None
    kakao: KakaoLoginBody | None = None
