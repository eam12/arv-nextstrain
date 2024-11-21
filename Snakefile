# Define wildcards
SEGMENTS = ["L1", "S1"]


"""This rule tells Snakemake that at the end of the pipeline, you should have
generated JSON files in the auspice folder for each segment."""
rule all:
    input:
        auspice_json = expand("auspice/arv-nextstrain_{segment}.json", segment=SEGMENTS)

# rule all:
#     input:
#         tree = expand("results/tree_{segment}.nwk", segment=SEGMENTS)

"""Specify all input files here. Specify here sequences.fasta and metadata.tsv files (required. Also any files denoting specific strains to include or drop,
references sequences, and files for auspice visualization"""
rule files:
    params:
        input_sequences = "data/sequences_{segment}.fasta",
        metadata = "data/metadata_{segment}.tsv",
        reference = "config/refs/reference_{segment}.gb",
        auspice_config = "config/auspice_config.json"

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

# augur align: Align multiple sequences from FASTA
# https://docs.nextstrain.org/projects/augur/en/stable/usage/cli/align.html

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


# augur tree: Build a tree using a variety of methods
# https://docs.nextstrain.org/projects/augur/en/stable/usage/cli/tree.html

rule tree:
    message: "Building tree"
    input:
        alignment = rules.align.output.alignment
    output:
        tree = "results/tree-raw_{segment}.nwk"
    params:
        method = "iqtree",
        model = "auto"
    shell:
        """
        augur tree \
            --alignment {input.alignment} \
            --output {output.tree} \
            --method {params.method} \
            --substitution-model {params.model} \
            --nthreads 1
        """


# augur refine: Refine an initial tree using sequence metadata
# https://docs.nextstrain.org/projects/augur/en/26.0.0/usage/cli/refine.html
# TreeTime: https://treetime.readthedocs.io/en/latest/index.html
rule refine:
    message:
        """
        Refining tree
          - estimate timetree
        """
    input:
        tree = rules.tree.output.tree,
        alignment = rules.align.output,
        metadata = files.metadata
    output:
        tree = "results/tree_{segment}.nwk",
        node_data = "results/branch-lengths_{segment}.json"
    params:
        metadata_id = "accession",
        divergence_units = "mutations"
    shell:
        """
        augur refine \
            --tree {input.tree} \
            --alignment {input.alignment} \
            --metadata {input.metadata} \
            --metadata-id-columns {params.metadata_id} \
            --divergence-units {params.divergence_units} \
            --output-tree {output.tree} \
            --output-node-data {output.node_data} \
        """


"""This rule exports the results of the pipeline into JSON format, which is required
for visualization in auspice. To make changes to the categories of metadata
that are colored, or how the data is visualized, alter the auspice_config files"""
rule export:
    message: "Exporting data files for for auspice"
    input:
        tree = rules.refine.output.tree,
        metadata = files.metadata,
        node_data = rules.refine.output.node_data,
        auspice_config = files.auspice_config
    output:
        auspice_json = "auspice/arv-nextstrain_{segment}.json"
    params:
        metadata_id = "accession"
    shell:
        """
        augur export v2 \
            --tree {input.tree} \
            --metadata {input.metadata} \
            --metadata-id-columns {params.metadata_id} \
            --node-data {input.node_data} \
            --auspice-config {input.auspice_config} \
            --output {output.auspice_json}
        """


# rule clean:
#     message: "Removing directories: {params}"
#     params:
#         "results ",
#         "auspice"
#     shell:
#         "rm -rfv {params}"

