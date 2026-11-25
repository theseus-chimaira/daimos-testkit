/* Source-linked DROP/PREFIX ownership uncertainty, v1918. */
static unsigned int fault_v1918;
static unsigned int unpins_v1918;

int
rebase_reply_v1918(kword_t base, unsigned int owner,
    kword_t prefix, kword_t words)
{
        int rc = mm_pure_rebase_pinned_v1381(base, owner, prefix, words);
        if (rc == MM_OK && fault_v1918 == 1U)
                return MM_ERR_BUSY;
        return rc;
}

int
claim_reply_v1918(kword_t base, unsigned int owner,
    kword_t prefix, kword_t words)
{
        int rc = mm_pure_claim_prefix_v1384(base, owner, prefix, words);
        if (rc == MM_OK && fault_v1918 == 2U)
                return MM_ERR_BUSY;
        return rc;
}

int
commit_reply_v1918(kword_t base, unsigned int owner,
    kword_t prefix, kword_t words)
{
        int rc = mm_pure_commit_prefix_v1384(base, owner, prefix, words);
        if (rc == MM_OK && fault_v1918 == 3U)
                return MM_ERR_BUSY;
        return rc;
}

int
release_reply_v1918(kword_t base, unsigned int owner,
    kword_t prefix, kword_t words)
{
        int rc = mm_pure_release_prefix_v1384(base, owner, prefix, words);
        if (rc == MM_OK && fault_v1918 == 4U)
                mm_extents[0].meta =
                    (mm_extents[0].meta & ~MM_OWNER_MASK) | (SLOT + 1U);
        if (rc == MM_OK && fault_v1918 == 5U)
                return MM_ERR_BUSY;
        return rc;
}

int
unpin_reply_v1918(kword_t base)
{
        ++unpins_v1918;
        return mm_unpin(base);
}

static int
load_v1918(kword_t backing, kword_t base, kword_t uarea, kword_t prefix)
{
        int rc = prefix_plain_v1384(backing, base, uarea, prefix);
        if (!rc && fault_v1918 == 6U)
                (void)mm_pin(base);
        if (fault_v1918 == 4U || fault_v1918 == 5U)
                return -1;
        return rc;
}
