
cdef struct Bucket:
    int item_size
    Bucket* next_bucket
    void *items     # SomeStruct items[ITEMS_PER_BUCKET]
    # NOTE:
    # I'd like to have the struct be:
    #
    # cdef struct Bucket:
    #   int item_size
    #   Bucket* next_bucket
    #   SomeStruct items[ITEMS_PER_BUCKET]
    #
    # where I can change out what "SomeStruct" is. To make this kinda
    # work I'm using void* in place of the array of SomeStruct. The void*
    # will act similar to SomeStruct items[ITEMS_PER_BUCKET]. This
    # requires some fancy footwork in bucket_make() and probably other
    # places. So watch out for some code that is not super straight
    # forward.


cdef struct BucketList:
    int size
    Bucket *head_bucket




cdef Bucket* bucket_make(int item_size)
cdef void bucket_del(Bucket* b)




cdef BucketList* bucket_list_make(int item_size)
cdef void bucket_list_del(BucketList* bl)
cdef void bucket_list_clear(BucketList* bl) nogil
cdef void* bucket_list_add_item(BucketList* bl) nogil
cdef void* bucket_list_get_item(BucketList* bl, int i) nogil
cdef void bucket_list_transfer_data(BucketList* l1, BucketList* l2)


