from typing import Annotated, Literal
import re
from pydantic import AfterValidator, BaseModel, ConfigDict, EmailStr, Field, StringConstraints, TypeAdapter, model_validator


def validate_username(value: str) -> str:
    if not re.fullmatch(r"(?!\.)(?!.*\.\.)(?!.*\.$)[A-Za-z0-9._]{1,30}", value):
        raise ValueError("Username must use 1-30 English letters, digits, underscores, or non-consecutive interior dots")
    return value


def validate_display_name(value: str) -> str:
    if not re.fullmatch(r"[A-Za-z0-9가-힣]+", value):
        raise ValueError("Nickname must use Korean syllables, English letters, or digits only")
    # 한글은 2단위, 영문·숫자는 1단위로 세어 혼합 이름도 같은 길이 규칙을 적용해요.
    units = sum(2 if "가" <= char <= "힣" else 1 for char in value)
    if not 4 <= units <= 12:
        raise ValueError("Nickname length must be 4-12 units (Korean syllables count as 2)")
    return value


Username = Annotated[str, StringConstraints(min_length=1, max_length=30), AfterValidator(validate_username)]
DisplayName = Annotated[str, StringConstraints(min_length=2, max_length=12), AfterValidator(validate_display_name)]
LegacyUsername = Annotated[str, StringConstraints(min_length=1, max_length=50)]


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
    display_name: DisplayName


class UserProfileUpdateBody(UserProfileBody):
    # 예전 규칙으로 만든 아이디는 닉네임을 처음 설정할 때 그대로 둘 수 있어요.
    username: LegacyUsername | None = None


class EmailCodeBody(BaseModel):
    email: EmailStr
    purpose: Literal["signup", "password_reset", "username_recovery"] = "signup"


class RegistrationAvailabilityBody(BaseModel):
    field: Literal["username", "display_name", "email"]
    value: str

    @model_validator(mode="after")
    def validate_value(self):
        # 중복 조회에도 실제 가입과 같은 형식·이메일 정규화 규칙을 적용해요.
        types = {"username": Username, "display_name": DisplayName, "email": EmailStr}
        self.value = str(TypeAdapter(types[self.field]).validate_python(self.value))
        return self


class CodeBody(BaseModel):
    challenge_id: str = Field(min_length=40, max_length=100)
    code: str = Field(pattern=r"^[0-9]{6}$")


class RegisterEmailBody(UserProfileBody, CodeBody):
    password: Password


class PasswordLoginBody(BaseModel):
    # 기존 클라이언트의 필드 이름을 유지하면서 이메일 최대 길이도 받아요.
    username: Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=254)]
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


class AccessTokenBody(BaseModel):
    # Kakao·LINE 로그인과 탈퇴에서 같은 토큰 입력 규칙을 사용해요.
    access_token: str = Field(min_length=1, max_length=10000)


class DeleteAccountBody(BaseModel):
    model_config = ConfigDict(extra="forbid")
    apple: AppleLoginBody | None = None
    kakao: AccessTokenBody | None = None
    line: AccessTokenBody | None = None
