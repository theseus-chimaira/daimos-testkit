/* KCC PDP-6 ABI regression: a saved parameter remains live after a store.
 *
 * The fully optimized compiler once emitted MOVE 1,10 without first
 * initializing preserved AC10 from the incoming AC1.  The immediate
 * result was a 24-descriptor table on 256K systems that need 136.
 * Keep this reproducer independent of DAIMOS's MM interfaces.
 */
extern unsigned int slots(unsigned long words);

unsigned long preserved_words;
unsigned int descriptor_count;

void
preserved_arg_before_call(unsigned long words)
{
        preserved_words = words;
        descriptor_count = 2U * slots(words) + 8U;
}

void
preserved_arg_simple(unsigned long words)
{
        preserved_words = words;
        descriptor_count = slots(words);
}

void
preserved_arg_other_order(unsigned long words)
{
        descriptor_count = slots(words);
        preserved_words = words;
}
