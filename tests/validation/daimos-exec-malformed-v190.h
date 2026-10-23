/*
 * Negative EXEC/RUN launch validation probes for the native PDP-6 fixture.
 * Run before the successful EXEC: every malformed block must return -1,
 * leaving the caller alive with its original image and mapped arguments.
 *
 * These tests intentionally never submit a valid RUN block: a failure in
 * the test itself must not create a child process.
 */
#ifndef DAIMOS_EXEC_MALFORMED_V190_H
#define DAIMOS_EXEC_MALFORMED_V190_H

#define MALFORMED_V190_LEFT_HALF_BIT 01000000UL

static int
malformed_v190_exec_word(struct sys_exec_v1 *block, kword_t *word,
    kword_t invalid)
{
        kword_t original;
        int result;

        original = *word;
        *word = invalid;
        result = dsys_exec(block);
        *word = original;
        return result == -1;
}

static int
malformed_v190_run_word(struct sys_run_v2 *block, kword_t *word,
    kword_t invalid)
{
        kword_t original;
        int result;

        original = *word;
        *word = invalid;
        result = dsys_run(block);
        *word = original;
        return result == -1;
}

static int
malformed_v190_check(kword_t *exec_words, unsigned int total,
    unsigned int path_words)
{
        struct sys_exec_v1 *exec;
        struct sys_run_v2 *run;
        kword_t run_words[SYS_RUN_V2_FIXED_WORDS + U_PATH_WORDS + 1U];
        unsigned int i;
        unsigned int run_total;

        exec = (struct sys_exec_v1 *)exec_words;
        if (!malformed_v190_exec_word(exec, &exec->version_words,
                SYS_RUN_HEADER(2U, total)) ||
            !malformed_v190_exec_word(exec, &exec->version_words,
                SYS_RUN_HEADER(SYS_EXEC_VERSION_1, 4U)) ||
            !malformed_v190_exec_word(exec, &exec->version_words,
                SYS_RUN_HEADER(SYS_EXEC_VERSION_1, 0777777U)) ||
            !malformed_v190_exec_word(exec, &exec->argc,
                MALFORMED_V190_LEFT_HALF_BIT) ||
            !malformed_v190_exec_word(exec, &exec->argc, 021UL) ||
            !malformed_v190_exec_word(exec, &exec->envc,
                MALFORMED_V190_LEFT_HALF_BIT) ||
            !malformed_v190_exec_word(exec, &exec->envc, 021UL) ||
            !malformed_v190_exec_word(exec,
                &exec_words[SYS_EXEC_V1_FIXED_WORDS], 0UL) ||
            !malformed_v190_exec_word(exec,
                &exec_words[SYS_EXEC_V1_FIXED_WORDS],
                MALFORMED_V190_LEFT_HALF_BIT) ||
            !malformed_v190_exec_word(exec,
                &exec_words[SYS_EXEC_V1_FIXED_WORDS], 0147UL) ||
            !malformed_v190_exec_word(exec,
                &exec_words[SYS_EXEC_V1_FIXED_WORDS], 0146UL) ||
            !malformed_v190_exec_word(exec,
                &exec_words[SYS_EXEC_V1_FIXED_WORDS + path_words],
                MALFORMED_V190_LEFT_HALF_BIT) ||
            !malformed_v190_exec_word(exec,
                &exec_words[SYS_EXEC_V1_FIXED_WORDS + path_words],
                0146UL) ||
            !malformed_v190_exec_word(exec, &exec->version_words,
                SYS_RUN_HEADER(SYS_EXEC_VERSION_1, total - 1U)))
                return 0;

        /* RUN V2 uses a six-word header, one valid counted path and no
         * fd mappings/arguments. Every probe below makes it invalid. */
        for (i = 0U; i < SYS_RUN_V2_FIXED_WORDS + U_PATH_WORDS + 1U; ++i)
                run_words[i] = 0UL;
        run = (struct sys_run_v2 *)run_words;
        run_total = SYS_RUN_V2_FIXED_WORDS + path_words;
        run->version_words = SYS_RUN_HEADER(SYS_RUN_VERSION_2, run_total);
        run->flags = SYS_RUN_PGRP_INHERIT;
        for (i = 0U; i < path_words; ++i)
                run_words[SYS_RUN_V2_FIXED_WORDS + i] =
                    exec_words[SYS_EXEC_V1_FIXED_WORDS + i];

        if (!malformed_v190_run_word(run, &run->version_words,
                SYS_RUN_HEADER(1U, run_total)) ||
            !malformed_v190_run_word(run, &run->version_words,
                SYS_RUN_HEADER(SYS_RUN_VERSION_2, 6U)) ||
            !malformed_v190_run_word(run, &run->version_words,
                SYS_RUN_HEADER(SYS_RUN_VERSION_2, 0777777U)) ||
            !malformed_v190_run_word(run, &run->fdmap_count,
                MALFORMED_V190_LEFT_HALF_BIT) ||
            !malformed_v190_run_word(run, &run->fdmap_count, 021UL) ||
            !malformed_v190_run_word(run, &run->argc,
                MALFORMED_V190_LEFT_HALF_BIT) ||
            !malformed_v190_run_word(run, &run->argc, 021UL) ||
            !malformed_v190_run_word(run, &run->envc,
                MALFORMED_V190_LEFT_HALF_BIT) ||
            !malformed_v190_run_word(run, &run->envc, 021UL) ||
            !malformed_v190_run_word(run,
                &run_words[SYS_RUN_V2_FIXED_WORDS], 0UL) ||
            !malformed_v190_run_word(run,
                &run_words[SYS_RUN_V2_FIXED_WORDS],
                MALFORMED_V190_LEFT_HALF_BIT) ||
            !malformed_v190_run_word(run,
                &run_words[SYS_RUN_V2_FIXED_WORDS], 0147UL) ||
            !malformed_v190_run_word(run,
                &run_words[SYS_RUN_V2_FIXED_WORDS], 0146UL) ||
            !malformed_v190_run_word(run, &run->version_words,
                SYS_RUN_HEADER(SYS_RUN_VERSION_2, run_total + 1U)))
                return 0;

        return 1;
}

#endif
