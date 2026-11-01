This document was inspired by perl5's [AI_POLICY.md](https://github.com/Perl/perl5/blob/blead/AI_POLICY.md).

## AI Usage Policy

AI usage in `aurutils` is subject to the following rules:

- Non-human interaction in the project is strictly prohibited. AI agents must not create issues or pull requests, post to the mailing list, or otherwise participate in any project communication channels.

- Non-human communication is disallowed. LLM-generated prose is grounds for dismissing a contribution out of hand, with the following exceptions:

  1. LLM-generated security analysis that has been verified by a qualified human prior to submission
  2. LLM use for translation of human-written messages

If you consider attempting such a submission, we strongly urge you to make an effort to curb the verbosity of LLM-generated text.

- LLM-assisted examination of the codebase is up to the contributor and does not require disclosure. Familiarity with the codebase is important and we are happy to see people make an effort to achieve it, but keep in mind that asking established contributors questions is a good option.

- LLM-written code contributions to the codebase may be accepted. Do not use an LLM to write code that you could not (with sufficient time available) have written yourself. `aurutils` is a complicated codebase which covers many use- and edge cases; it requires significant familiarity to successfully judge the quality of a large patch. Do not expect a submission to be accepted if you do not sufficiently understand design decisions to defend them in detail, or if you would not be able to maintain your changes over the long run yourself.

- Comments in generated code must be reviewed prior to submission and not be irrelevant or overly verbose.

- The fact that AI was used to generate any part of any contribution or communication must be disclosed. Accountability for any contribution lies with the contributor who submitted it. You must ensure you can submit it under the license of the project, and provide attribution to sources where necessary.
