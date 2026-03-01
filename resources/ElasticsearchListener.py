"""
Robot Framework Listener for Elasticsearch Integration

Uploads test results to Elasticsearch in real-time as tests complete.
Used as: --listener resources.ElasticsearchListener
"""

import os
import sys
import logging
from datetime import datetime
from pathlib import Path

try:
    from elasticsearch import Elasticsearch
except ImportError:
    Elasticsearch = None

logger = logging.getLogger(__name__)

# Add resources to path for config imports
_resources_dir = str(Path(__file__).parent)
if _resources_dir not in sys.path:
    sys.path.insert(0, _resources_dir)


class ElasticsearchListener:
    """Robot Framework listener that uploads results to Elasticsearch."""

    ROBOT_LISTENER_API_VERSION = 3

    def __init__(self, es_host=None, es_port=None, index_prefix=None):
        self.es_host = es_host or os.getenv('ELASTICSEARCH_HOST', 'localhost')
        self.es_port = int(es_port or os.getenv('ELASTICSEARCH_PORT', '9200'))
        self.index_prefix = index_prefix or 'rf-automation'
        self.client = None
        self.suite_name = ''
        self.build_number = os.getenv('BUILD_NUMBER', '0')
        self.branch = os.getenv('GIT_BRANCH', os.getenv('BRANCH_NAME', 'unknown'))
        self._connect()

    def _connect(self):
        if Elasticsearch is None:
            logger.warning("elasticsearch package not installed, skipping ES upload")
            return

        url = f"http://{self.es_host}:{self.es_port}"
        try:
            self.client = Elasticsearch([url])
            if self.client.ping():
                logger.info(f"Connected to Elasticsearch at {url}")
                self._ensure_index()
            else:
                logger.warning(f"Elasticsearch not reachable at {url}")
                self.client = None
        except Exception as e:
            logger.warning(f"Failed to connect to Elasticsearch: {e}")
            self.client = None

    def _get_index_name(self):
        date_suffix = datetime.now().strftime("%Y.%m")
        return f"{self.index_prefix}-{date_suffix}"

    def _ensure_index(self):
        if not self.client:
            return
        index = self._get_index_name()
        try:
            if not self.client.indices.exists(index=index):
                mapping = {
                    "mappings": {
                        "properties": {
                            "@timestamp": {"type": "date"},
                            "suite_name": {"type": "keyword"},
                            "test_name": {"type": "text", "fields": {"keyword": {"type": "keyword"}}},
                            "status": {"type": "keyword"},
                            "message": {"type": "text"},
                            "duration_ms": {"type": "float"},
                            "tags": {"type": "keyword"},
                            "build_number": {"type": "keyword"},
                            "branch": {"type": "keyword"},
                        }
                    }
                }
                self.client.indices.create(index=index, body=mapping)
                logger.info(f"Created index: {index}")
        except Exception as e:
            logger.warning(f"Failed to create index: {e}")

    def start_suite(self, data, result):
        if data.parent is None:
            self.suite_name = data.name

    def end_test(self, data, result):
        if not self.client:
            return

        start = result.starttime
        end = result.endtime

        duration_ms = 0
        if start and end:
            try:
                duration_ms = (end - start).total_seconds() * 1000
            except Exception:
                duration_ms = 0

        doc = {
            "@timestamp": datetime.utcnow().isoformat(),
            "suite_name": self.suite_name,
            "test_name": result.name,
            "status": result.status,
            "message": result.message or "",
            "duration_ms": duration_ms,
            "tags": list(result.tags),
            "build_number": self.build_number,
            "branch": self.branch,
        }

        try:
            self.client.index(index=self._get_index_name(), body=doc)
            logger.debug(f"Uploaded result: {result.name} [{result.status}]")
        except Exception as e:
            logger.warning(f"Failed to upload test result: {e}")

    def close(self):
        if self.client:
            logger.info("Elasticsearch listener closed")
