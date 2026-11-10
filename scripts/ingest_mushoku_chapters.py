#!/usr/bin/env python3
"""
Mushoku Tensei authentic opening chapters ingestion pointer.
Delegates to seed_comprehensive_catalog.py to ensure authentic main story panels.
"""

from __future__ import annotations

import asyncio
from pathlib import Path
import sys

SCRIPTS_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPTS_DIR))

from seed_comprehensive_catalog import main

if __name__ == "__main__":
    asyncio.run(main())
