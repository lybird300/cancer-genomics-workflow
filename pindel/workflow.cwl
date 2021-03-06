#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: Workflow
label: "pindel parallel workflow"
requirements:
    - class: ScatterFeatureRequirement
    - class: MultipleInputFeatureRequirement
    - class: SubworkflowFeatureRequirement
inputs:
    reference:
        type: File
        secondaryFiles: [".fai"]
    tumor_bam:
        type: File
        secondaryFiles: ["^.bai"]
    normal_bam:
        type: File
        secondaryFiles: ["^.bai"]
    interval_list:
        type: File
    insert_size:
        type: int
        default: 400
outputs:
    merged_vcf:
        type: File
        outputSource: index_filtered/indexed_vcf
        secondaryFiles: [".tbi"]
steps:
    get_tumor_bam_index:
        run: get_bam_index.cwl
        in:
            bam: tumor_bam
        out:
            [bam_index]
    get_normal_bam_index:
        run: get_bam_index.cwl
        in:
            bam: normal_bam
        out:
            [bam_index]
    get_chromosome_list:
        run: get_chromosome_list.cwl
        in: 
            interval_list: interval_list
        out:
            [chromosome_list]
    pindel_cat:
        scatter: chromosome
        run: pindel_cat.cwl
        in:
            reference: reference
            tumor_bam: tumor_bam
            normal_bam: normal_bam
            tumor_bam_index: [get_tumor_bam_index/bam_index]
            normal_bam_index: [get_normal_bam_index/bam_index]
            chromosome: [get_chromosome_list/chromosome_list]
            insert_size: insert_size
        out:
            [per_chromosome_pindel_out]
    cat_all:
        run: cat_all.cwl
        in:
            chromosome_pindel_outs: [pindel_cat/per_chromosome_pindel_out]
        out:
            [all_chromosome_pindel_out]
    grep:
        run: grep.cwl
        in: 
           pindel_output: cat_all/all_chromosome_pindel_out
        out:
           [pindel_head] 
    somaticfilter:
        run: somaticfilter.cwl
        in:
            reference: reference
            pindel_output_summary: grep/pindel_head
        out: 
            [vcf]
    bgzip:
        run: ../detect_variants/bgzip.cwl
        in: 
            file: somaticfilter/vcf
        out:
            [bgzipped_file]
    index:
        run: ../detect_variants/index.cwl
        in:
            vcf: bgzip/bgzipped_file
        out:
            [indexed_vcf]
    region_filter:
        run: ../detect_variants/select_variants.cwl
        in:
            reference: reference
            vcf: index/indexed_vcf
            interval_list: interval_list
        out:
            [filtered_vcf]
    index_filtered:
        run: ../detect_variants/index.cwl
        in:
            vcf: region_filter/filtered_vcf
        out:
            [indexed_vcf]
