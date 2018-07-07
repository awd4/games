cimport cython
from libc.string cimport memcpy
from libc.stdint cimport uintptr_t, int8_t, int32_t
from cpython.mem cimport PyMem_Malloc, PyMem_Free


DEF ITEMS_PER_BUCKET = 10000




cdef Bucket* bucket_make(int item_size) nogil:
    cdef uintptr_t offset = <uintptr_t>&(<Bucket *>NULL).items
    cdef Bucket *b
    with gil:
        b = <Bucket *>PyMem_Malloc(offset + item_size * ITEMS_PER_BUCKET)
    b.item_size = item_size
    b.next_bucket = NULL
    return b

cdef void bucket_del(Bucket* b):
    PyMem_Free(b)




cdef BucketList* bucket_list_make(int item_size):
    cdef BucketList *bl = <BucketList *>PyMem_Malloc(1 * sizeof(BucketList))
    bl.head_bucket = bucket_make(item_size)
    bl.size = 0
    return bl

cdef void bucket_list_del(BucketList* bl):
    cdef Bucket *curr
    cdef Bucket *tmp
    if bl == NULL:
        return
    bl.size = 0
    curr = bl.head_bucket
    while curr != NULL:
        tmp = curr.next_bucket
        bucket_del(curr)
        curr = tmp
    bl.head_bucket = NULL
    PyMem_Free(bl)

cdef void bucket_list_clear(BucketList* bl) nogil:
    bl.size = 0

@cython.cdivision(True)
cdef void* bucket_list_add_item(BucketList* bl) nogil:
    cdef int i = bl.size
    cdef Bucket *curr = bl.head_bucket
    while i >= ITEMS_PER_BUCKET:
        i -= ITEMS_PER_BUCKET
        if curr.next_bucket == NULL:
            curr.next_bucket = bucket_make(curr.item_size)
        curr = curr.next_bucket
    bl.size += 1
    cdef uintptr_t addr = <uintptr_t>&curr.items + i * curr.item_size
    return <void *>addr

@cython.cdivision(True)
cdef void* bucket_list_get_item(BucketList* bl, int i) nogil:
    if i < 0 or i >= bl.size:
        return NULL
    cdef Bucket *curr = bl.head_bucket
    while i >= ITEMS_PER_BUCKET:
        i -= ITEMS_PER_BUCKET
        if curr.next_bucket == NULL:
            return NULL
        curr = curr.next_bucket
    cdef uintptr_t addr = <uintptr_t>&curr.items + i * curr.item_size
    return <void *>addr

@cython.cdivision(True)
cdef void bucket_list_transfer_data(BucketList* l1, BucketList* l2):
    cdef int i, j, l1_last_size, l2_last_size
    cdef Bucket *l1_last = l1.head_bucket
    cdef Bucket *l2_last = l2.head_bucket
    cdef Bucket *tmp1 = NULL
    cdef Bucket *tmp2 = NULL
    cdef uintptr_t addr1 = 0
    cdef uintptr_t addr2 = 0

    if l2.size <= 0:
        return

    l1_last_size = l1.size
    while l1_last.next_bucket != NULL and l1_last_size > ITEMS_PER_BUCKET:
        l1_last = l1_last.next_bucket
        l1_last_size -= ITEMS_PER_BUCKET

    l2_last_size = l2.size
    while l2_last.next_bucket != NULL:
        l2_last = l2_last.next_bucket
        l2_last_size -= ITEMS_PER_BUCKET

    # prune off any extra, unused buckets in l1
    if l1_last.next_bucket != NULL:
        tmp1 = l1_last.next_bucket
        while tmp1 != NULL:
            tmp2 = tmp1.next_bucket
            bucket_del(tmp1)
            tmp1 = tmp2

    # switch data from l2 into l1
    l1_last.next_bucket = l2.head_bucket
    l1.size += l2.size

    # make l2 empty, but still usable
    l2.head_bucket = bucket_make(l2.head_bucket.item_size)
    l2.head_bucket.next_bucket = NULL
    l2.size = 0

    tmp2 = l2_last
    j = l2_last_size - 1
    for i in range(l1_last_size, ITEMS_PER_BUCKET):
        addr1 = <uintptr_t>&l1_last.items + i * l1_last.item_size
        addr2 = <uintptr_t>&tmp2.items + j * tmp2.item_size
        memcpy(<void *>addr1, <void *>addr2, tmp2.item_size)

        j -= 1
        if j < 0:
            # move to the second-to-last bucket, since the last is now empty
            tmp2 = l1.head_bucket
            while tmp2.next_bucket != l2_last:
                tmp2 = tmp2.next_bucket
            j = ITEMS_PER_BUCKET - 1




cdef struct State:
    int8_t board[64]
    int8_t history[60]
    int32_t turn

def test():

    cdef BucketList *bl = bucket_list_make(sizeof(State))

    cdef int i = 0
    for i in range(ITEMS_PER_BUCKET + 10):
        bucket_list_add_item(bl)
    cdef State* s = <State *>bucket_list_get_item(bl, 10)

    bucket_list_del(bl)




