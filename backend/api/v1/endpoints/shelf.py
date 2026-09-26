from uuid import UUID
from fastapi import APIRouter, Header, Query
from schemas import ShelfSyncPayload, ShelfSyncResponse, ShelfSyncItemDTO
from services import auth_service, shelf_sync

router = APIRouter()

@router.post("/shelf/sync", response_model=ShelfSyncResponse)
def sync_shelf(payload: ShelfSyncPayload, authorization: str = Header(None)):
    user = auth_service.get_current_user_from_header(authorization)
    return shelf_sync.sync_shelf(payload, user.id)

@router.get("/shelf", response_model=list[ShelfSyncItemDTO])
def get_shelf(
    device_id: UUID = Query(..., alias="deviceId"),
    authorization: str = Header(None),
):
    user = auth_service.get_current_user_from_header(authorization)
    return shelf_sync.get_shelf(device_id, user.id)
