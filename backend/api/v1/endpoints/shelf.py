from uuid import UUID
from fastapi import APIRouter, Query
from schemas import ShelfSyncPayload, ShelfSyncResponse, ShelfSyncItemDTO
from services import shelf_sync

router = APIRouter()

@router.post("/shelf/sync", response_model=ShelfSyncResponse)
def sync_shelf(payload: ShelfSyncPayload):
    return shelf_sync.sync_shelf(payload)

@router.get("/shelf", response_model=list[ShelfSyncItemDTO])
def get_shelf(device_id: UUID = Query(..., alias="deviceId")):
    return shelf_sync.get_shelf(device_id)
