#!/usr/bin/env python3
"""MemVault Basic Usage Examples."""

import requests
import json

BASE_URL = "http://localhost:8002"
USER_ID = "demo_user"

def memorize_conversation():
    """Store a conversation."""
    conversation = [
        {"role": "user", "content": "I'm learning Python and really enjoying it"},
        {"role": "assistant", "content": "That's great! What aspects do you find most interesting?"},
        {"role": "user", "content": "I like how readable it is compared to Java"},
    ]
    
    resp = requests.post(
        f"{BASE_URL}/memorize",
        json={"conversation": conversation, "user_id": USER_ID}
    )
    print("Memorize:", resp.json())


def retrieve_memories():
    """Retrieve relevant memories."""
    resp = requests.post(
        f"{BASE_URL}/retrieve",
        json={"query": "what programming languages does the user know?", "user_id": USER_ID, "limit": 3}
    )
    data = resp.json()
    print(f"\nRetrieved {len(data['memories'])} memories:")
    for mem in data['memories']:
        print(f"  - {mem['summary']} (strength: {mem['strength']:.2f}, score: {mem['score']:.3f})")


def check_stats():
    """Check memory statistics."""
    resp = requests.get(f"{BASE_URL}/stats?user_id={USER_ID}")
    stats = resp.json()
    print(f"\nMemory Stats:")
    print(f"  Total: {stats['total']}")
    print(f"  Distribution: strong={stats['distribution']['strong']}, "
          f"medium={stats['distribution']['medium']}, weak={stats['distribution']['weak']}")
    print(f"  Avg strength: {stats['avg_strength']:.3f}")


if __name__ == "__main__":
    print("=== MemVault Basic Usage ===\n")
    memorize_conversation()
    retrieve_memories()
    check_stats()
