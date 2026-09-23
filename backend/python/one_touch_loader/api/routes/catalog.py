from fastapi import APIRouter, Depends

from ..deps import get_user_id
from ..repos.catalog_repo import get_catalog
from ..schemas.catalog import CatalogResponse

router = APIRouter()


@router.get("/catalog", response_model=CatalogResponse)
def catalog(user_id: int = Depends(get_user_id)):
    return get_catalog()
