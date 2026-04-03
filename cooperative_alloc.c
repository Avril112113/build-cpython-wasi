#include <stdlib.h>
#include <stdint.h>

/**
 * Allocates a buffer of the specified size.
 * 
 * @param size The number of bytes to allocate.
 * @return The 32-bit pointer (offset) to the allocated memory, 
 *         or -1 if the allocation fails.
 */
int32_t asyncify_malloc_buffer(int32_t size)
{
    // Check for invalid request
    if (size <= 0) {
        return -1;
    }

    // Allocate
    void* ptr = malloc((size_t)size);
    if (ptr == NULL) {
        return -1;
    }

    // Ensure the pointer fits in a positive int32.
    if ((uintptr_t)ptr > (uintptr_t)INT32_MAX) {
        free(ptr);
        return -1; 
    }

    return (int32_t)(uintptr_t)ptr;
}

/**
 * Frees a buffer previously allocated by asyncify_malloc_buffer.
 * 
 * @param ptr  The 32-bit pointer to the buffer to be freed.
 * @param size The size of the buffer (provided for compatibility/tracking).
 */
void asyncify_free_buffer(int32_t ptr, int32_t size)
{
    // If the pointer is 0 (NULL) or size is invalid, we skip freeing
    // to prevent undefined behavior, though standard free(NULL) is safe.
    if (ptr == 0) {
        return;
    }

    free((void*)(uintptr_t)ptr);
}