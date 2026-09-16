from fastapi import APIRouter
from schemas import ShelfSyncPayload, ShelfSyncResponse
from services import shelf_sync

router = APIRouter()

@router.post("/shelf/sync", response_model=ShelfSyncResponse)
def sync_shelf(payload: ShelfSyncPayload):
    return shelf_sync.sync_shelf(payload)
