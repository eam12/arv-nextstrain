# Define wildcards
SEGMENTS = ["L1", "S1"]


# """This rule tells Snakemake that at the end of the pipeline, you should have
# generated JSON files in the auspice folder for each segment."""
# rule all:
#     input:
#         auspice_json = expand("auspice/arv-nextstrain_{segment}.json", segment=SEGMENTS)

rule all:
    input:
        alignment = expand("results/aligned_{segment}.fasta", segment=SEGMENTS)

"""Specify all input files here. Specify here sequences.fasta and metadata.tsv files (required. Also any files denoting specific strains to include or drop,
references sequences, and files for auspice visualization"""
rule files:
    params:
        input_sequences = "data/sequences_{segment}.fasta",
        metadata = "data/metadata_{segment}.tsv",
        reference = "config/reference_{segment}.gb"

files = rules.files.params


"""The minimum length required for sequences. Sequences shorter than these will be
subsampled out of the build. Here, we're requiring all segments to be basically
complete. To include partial genomes, shorten these to your desired length"""
def min_length(w):
    len_dict = {"L1": 3500, "S1":1200}
    length = len_dict[w.segment]
    return(length)



"""In this section of the Snakefile, rules are specified for each step of the pipeline.
Each rule has inputs, outputs, parameters, and the specific text for the commands in
bash. Rules reference each other, so altering one rule may require changing another
if they depend on each other for inputs and outputs. Notes are included for
specific rules."""


# """This rule specifies how to subsample data for the build, which is highly
# customizable based on your desired tree."""
# rule filter:
#     message:
#         """
#         Filtering to
#           - {params.sequences_per_group} sequence(s) per {params.group_by!s}
#           - excluding strains in {input.exclude}
#           - samples with missing region and country metadata
#           - excluding strains prior to {params.min_date}
#         """
#     input:
#         sequences = rules.parse.output.sequences,
#         metadata = rules.parse.output.metadata,
#         exclude = files.dropped_strains,
#         include = files.include_strains
#     output:
#         sequences = "results/filtered_{subtype}_{segment}.fasta"
#     params:
#         group_by = group_by,
#         sequences_per_group = sequences_per_group,
#         min_date = min_date,
#         min_length = min_length,
#         exclude_where = "host=laboratoryderived host=ferret host=unknown host=other country=? region=?"
#     shell:
#         """
#         augur filter \
#             --sequences {input.sequences} \
#             --metadata {input.metadata} \
#             --exclude {input.exclude} \
#             --include {input.include} \
#             --output {output.sequences} \
#             --group-by {params.group_by} \
#             --sequences-per-group {params.sequences_per_group} \
#             --min-date {params.min_date} \
#             --exclude-where {params.exclude_where} \
#             --min-length {params.min_length} \
#             --non-nucleotide
#         """


rule align:
    message:
        """
        Aligning sequences to {input.reference}
          - filling gaps with N
        """
    input:
        sequences = files.input_sequences,
        reference = files.reference
    output:
        alignment = "results/aligned_{segment}.fasta"
    shell:
        """
        augur align \
            --sequences {input.sequences} \
            --reference-sequence {input.reference} \
            --output {output.alignment} \
            --nthreads 1
        """









