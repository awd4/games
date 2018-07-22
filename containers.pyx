cimport cython
from libc.string cimport memcpy
from libc.stdint cimport uintptr_t, int8_t, int32_t
from libc.stdlib cimport malloc, free
from cpython.mem cimport PyMem_Malloc, PyMem_Free


DEF ITEMS_PER_BUCKET = 2000000



cdef Bucket* bucket_make(int item_size) nogil:
    cdef uintptr_t offset = <uintptr_t>&(<Bucket *>NULL).items
    cdef Bucket *b = <Bucket *>malloc(offset + item_size * ITEMS_PER_BUCKET)
#    with gil:
#        b = <Bucket *>PyMem_Malloc(offset + item_size * ITEMS_PER_BUCKET)
    b.item_size = item_size
    b.next_bucket = NULL
    return b

cdef void bucket_del(Bucket* b):
#    PyMem_Free(b)
    free(b)




cdef BucketList* bucket_list_make(int item_size):
    cdef BucketList *bl = <BucketList *>PyMem_Malloc(1 * sizeof(BucketList))
    bl.head_bucket = bucket_make(item_size)
    bl.tail_bucket = bl.head_bucket
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
    bl.tail_bucket = NULL
    PyMem_Free(bl)

cdef void bucket_list_clear(BucketList* bl) nogil:
    bl.tail_bucket = bl.head_bucket
    bl.size = 0

@cython.cdivision(True)
cdef void* bucket_list_add_item(BucketList* bl) nogil:
    cdef Bucket *last = bl.tail_bucket
    cdef int i = bl.size % ITEMS_PER_BUCKET
    if i == ITEMS_PER_BUCKET - 1:
        if last.next_bucket == NULL:
            last.next_bucket = bucket_make(last.item_size)
        last = last.next_bucket
        i = 0
    bl.size += 1
    cdef uintptr_t addr = <uintptr_t>&last.items + i * last.item_size
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
    cdef int i, j, l1_tail_size, l2_tail_size
    cdef Bucket *l1_last = l1.tail_bucket
    cdef Bucket *l2_last = l2.tail_bucket
    cdef Bucket *tmp1 = NULL
    cdef Bucket *tmp2 = NULL
    cdef uintptr_t addr1 = 0
    cdef uintptr_t addr2 = 0

    if l2.size <= 0:
        return

    # prune off any extra, unused buckets in l1
    if l1.tail_bucket.next_bucket != NULL:
        tmp1 = l1.tail_bucket.next_bucket
        l1.tail_bucket.next_bucket = NULL
        while tmp1 != NULL:
            tmp2 = tmp1.next_bucket
            bucket_del(tmp1)
            tmp1 = tmp2

    l1_tail_size = l1.size % ITEMS_PER_BUCKET
    l2_tail_size = l2.size % ITEMS_PER_BUCKET

    # switch data from l2 into l1
    tmp1 = l1.tail_bucket
    tmp1.next_bucket = l2.head_bucket
    l1.tail_bucket = l2.tail_bucket
    l1.size += l2.size

    # make l2 empty, but still usable
    l2.head_bucket = bucket_make(l2.head_bucket.item_size)
    l2.head_bucket.next_bucket = NULL
    l2.tail_bucket = l2.head_bucket
    l2.size = 0

    # move items from the new tail of l1 into the old tail of l1
    tmp2 = l1.tail_bucket
    j = l2_tail_size - 1
    for i in range(l1_tail_size, ITEMS_PER_BUCKET):
        addr1 = <uintptr_t>&tmp1.items + i * tmp1.item_size
        addr2 = <uintptr_t>&tmp2.items + j * tmp2.item_size
        memcpy(<void *>addr1, <void *>addr2, tmp2.item_size)

        j -= 1
        if j < 0:
            # move to the second-to-last bucket, since the last is now empty
            tmp2 = tmp1
            while tmp2.next_bucket != l1.tail_bucket:
                tmp2 = tmp2.next_bucket
            l1.tail_bucket = tmp2
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




