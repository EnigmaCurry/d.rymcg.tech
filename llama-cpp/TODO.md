# TODO

## Memory Management Research

Research how llama.cpp handles:
1. GPU memory usage - does it have to use all GPU memory or can it be limited?
2. Auto-management of memory resources

## Custom Image with Idle Model Unload Wrapper

Build a custom Docker image instead of pulling the upstream one, so we can add a wrapper script that:
1. Launches `llama-server`
2. Runs a background process that watches HTTP traffic to the server
3. Unloads the currently-loaded model if no request has been received in the last X seconds (configurable timeout)

(ideas in this conversation, which user has access to but agent doesn't: https://gulchwizard.thewooskeys.com/c/023e7aeb-d73e-4c4c-bceb-03243b8daac4)

This would free up GPU/RAM when the server is idle, while keeping the container running for quick warm-up on the next request.

## Research Links

- [Jan AI - Local Engine](https://www.jan.ai/docs/desktop/local-engine/llama-cpp)
