#!/usr/bin/env python3
"""
Upload Robot Framework Test Results to Elasticsearch

This script parses Robot Framework output.xml files and uploads
test results to Elasticsearch for analysis in Kibana.

Usage:
    python upload_to_elastic.py --results-file results/output.xml
"""

import argparse
import json
import sys
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional
from xml.etree import ElementTree as ET

try:
    from elasticsearch import Elasticsearch, helpers
    from loguru import logger
except ImportError as e:
    print(f"ERROR: Required library not installed: {e}")
    print("Run: pip install elasticsearch loguru")
    sys.exit(1)

# Add resources to path
sys.path.insert(0, str(Path(__file__).parent.parent / "resources"))

try:
    from network_vars import ELASTIC_ENDPOINT, get_elastic_index_name
except ImportError:
    ELASTIC_ENDPOINT = "http://localhost:9200"

    def get_elastic_index_name(test_suite="general"):
        return f"rf-automation-{test_suite}-{datetime.now().strftime('%Y.%m')}"


class RobotResultsParser:
    """Parse Robot Framework XML results."""

    def __init__(self, xml_file: Path):
        """Initialize parser with XML file path."""
        self.xml_file = xml_file
        self.tree = None
        self.root = None

    def parse(self) -> Dict:
        """Parse XML file and extract test results."""
        logger.info(f"Parsing Robot Framework results: {self.xml_file}")

        try:
            self.tree = ET.parse(self.xml_file)
            self.root = self.tree.getroot()
        except ET.ParseError as e:
            logger.error(f"Failed to parse XML: {e}")
            raise

        return {
            "metadata": self._extract_metadata(),
            "statistics": self._extract_statistics(),
            "suites": self._extract_suites(),
            "tests": self._extract_tests(),
        }

    def _extract_metadata(self) -> Dict:
        """Extract suite metadata."""
        suite = self.root.find("suite")

        return {
            "suite_name": suite.get("name", "Unknown"),
            "source": suite.get("source", ""),
            "timestamp": datetime.now().isoformat(),
            "generator": self.root.attrib.get("generator", "Robot Framework"),
        }

    def _extract_statistics(self) -> Dict:
        """Extract test statistics."""
        stats = self.root.find(".//statistics")
        total = stats.find(".//total/stat")

        return {
            "total": int(total.get("pass", 0)) + int(total.get("fail", 0)),
            "passed": int(total.get("pass", 0)),
            "failed": int(total.get("fail", 0)),
            "skipped": int(total.get("skip", 0)),
        }

    def _extract_suites(self) -> List[Dict]:
        """Extract suite information."""
        suites = []

        for suite in self.root.findall(".//suite"):
            status = suite.find("status")

            suite_data = {
                "name": suite.get("name"),
                "source": suite.get("source", ""),
                "status": status.get("status") if status is not None else "UNKNOWN",
                "start_time": status.get("starttime") if status is not None else None,
                "end_time": status.get("endtime") if status is not None else None,
            }

            suites.append(suite_data)

        return suites

    def _extract_tests(self) -> List[Dict]:
        """Extract individual test results."""
        tests = []

        for test in self.root.findall(".//test"):
            status = test.find("status")

            test_data = {
                "name": test.get("name"),
                "status": status.get("status") if status is not None else "UNKNOWN",
                "message": status.text if status is not None else "",
                "start_time": status.get("starttime") if status is not None else None,
                "end_time": status.get("endtime") if status is not None else None,
                "critical": status.get("critical", "yes") == "yes",
                "tags": [tag.text for tag in test.findall(".//tag")],
            }

            tests.append(test_data)

        return tests


class ElasticsearchUploader:
    """Upload test results to Elasticsearch."""

    def __init__(self, endpoint: str, index_name: str):
        """Initialize Elasticsearch connection."""
        self.endpoint = endpoint
        self.index_name = index_name
        self.client = None

    def connect(self) -> bool:
        """Connect to Elasticsearch."""
        logger.info(f"Connecting to Elasticsearch: {self.endpoint}")

        try:
            self.client = Elasticsearch([self.endpoint])

            # Verify connection
            if not self.client.ping():
                logger.error("Failed to ping Elasticsearch")
                return False

            logger.success("Connected to Elasticsearch")
            return True

        except Exception as e:
            logger.error(f"Elasticsearch connection failed: {e}")
            return False

    def create_index(self):
        """Create index with mapping if it doesn't exist."""
        if self.client.indices.exists(index=self.index_name):
            logger.info(f"Index already exists: {self.index_name}")
            return

        mapping = {
            "mappings": {
                "properties": {
                    "timestamp": {"type": "date"},
                    "suite_name": {"type": "keyword"},
                    "test_name": {"type": "text"},
                    "status": {"type": "keyword"},
                    "duration": {"type": "float"},
                    "tags": {"type": "keyword"},
                    "build_number": {"type": "integer"},
                    "branch": {"type": "keyword"},
                }
            }
        }

        self.client.indices.create(index=self.index_name, body=mapping)
        logger.success(f"Created index: {self.index_name}")

    def upload_results(self, results: Dict, build_number: Optional[int] = None,
                      branch: Optional[str] = None) -> bool:
        """Upload parsed results to Elasticsearch."""
        logger.info("Uploading results to Elasticsearch...")

        try:
            # Prepare documents for bulk upload
            docs = []

            for test in results["tests"]:
                doc = {
                    "_index": self.index_name,
                    "_source": {
                        "timestamp": results["metadata"]["timestamp"],
                        "suite_name": results["metadata"]["suite_name"],
                        "test_name": test["name"],
                        "status": test["status"],
                        "message": test["message"],
                        "tags": test["tags"],
                        "start_time": test["start_time"],
                        "end_time": test["end_time"],
                        "build_number": build_number,
                        "branch": branch,
                        "statistics": results["statistics"],
                    }
                }
                docs.append(doc)

            # Bulk upload
            success, failed = helpers.bulk(self.client, docs, stats_only=True)

            logger.success(f"Uploaded {success} documents, {failed} failed")
            return failed == 0

        except Exception as e:
            logger.error(f"Upload failed: {e}")
            return False


def main():
    """Main execution function."""
    parser = argparse.ArgumentParser(
        description="Upload Robot Framework results to Elasticsearch"
    )
    parser.add_argument(
        "--results-file",
        type=Path,
        default=Path("results/output.xml"),
        help="Path to Robot Framework output.xml file"
    )
    parser.add_argument(
        "--elastic-url",
        type=str,
        default=ELASTIC_ENDPOINT,
        help="Elasticsearch endpoint URL"
    )
    parser.add_argument(
        "--index-name",
        type=str,
        help="Elasticsearch index name (auto-generated if not provided)"
    )
    parser.add_argument(
        "--build-number",
        type=int,
        help="Jenkins build number"
    )
    parser.add_argument(
        "--branch",
        type=str,
        default="main",
        help="Git branch name"
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Enable verbose logging"
    )

    args = parser.parse_args()

    # Configure logging
    logger.remove()
    log_level = "DEBUG" if args.verbose else "INFO"
    logger.add(sys.stderr, level=log_level)
    logger.add("logs/upload_to_elastic.log", rotation="10 MB", level="DEBUG")

    # Validate input file
    if not args.results_file.exists():
        logger.error(f"Results file not found: {args.results_file}")
        return 1

    # Parse results
    try:
        parser_obj = RobotResultsParser(args.results_file)
        results = parser_obj.parse()

        logger.info(f"Parsed {len(results['tests'])} test cases")
        logger.info(f"Statistics: {results['statistics']}")

    except Exception as e:
        logger.error(f"Failed to parse results: {e}")
        return 1

    # Upload to Elasticsearch
    index_name = args.index_name or get_elastic_index_name(
        results["metadata"]["suite_name"]
    )

    uploader = ElasticsearchUploader(args.elastic_url, index_name)

    if not uploader.connect():
        logger.warning("Skipping Elasticsearch upload (connection failed)")
        return 0  # Don't fail the pipeline

    uploader.create_index()

    if uploader.upload_results(results, args.build_number, args.branch):
        logger.success("Upload completed successfully")
        return 0
    else:
        logger.error("Upload failed")
        return 1


if __name__ == "__main__":
    sys.exit(main())
