
process prepareInput {
    container 'docker://maximilianheeg/docker-scanpy:v1.9.5_pyarrow'
    cpus 8
    memory { 20.GB * task.attempt }
    time { 4.hour * task.attempt }
    errorStrategy 'ignore'
    input:
        path 'script.py'
        path 'input.csv'
    output:
        path 'ranger_transcripts.csv', emit: transcripts
        path 'output.geojson', emit: polygons

    """
        python script.py \
            --input input.csv \
            --output-geojson output.geojson \
            --output-csv ranger_transcripts.csv \
            --alpha $params.xeniumranger.alpha

    """
}

process runXeniumRanger {
    container 'docker://maximilianheeg/xeniumranger:v3.1.0'
    cpus 8
    memory { 40.GB * task.attempt }
    time { 4.hour * task.attempt }
    errorStrategy 'ignore'

    input:
        path "xenium_output"
        path "transcripts.csv"
        path "polygons.geojson"

    output:
        path "xenium-baysor/outs/*"

    publishDir "$params.outdir",
        mode: 'copy',
        overwrite: true,
        saveAs: { filename ->
            def relativePath = filename.toString() - "xenium-baysor/outs/"
            return "${relativePath}"
        }

    """
    xeniumranger import-segmentation\
         --id=xenium-baysor \
         --xenium-bundle=xenium_output \
         --transcript-assignment=transcripts.csv \
         --viz-polygons=polygons.geojson \
         --units=microns \
         --localcores=8

    """
}


workflow XeniumRanger {
    take:
        ch_baysor_segmentation
        ch_xenium_output

    main:

        rangerInput = prepareInput(
             Channel.fromPath("$baseDir/scripts/prepare_input_xenium_ranger.py"),
             ch_baysor_segmentation
        )


        runXeniumRanger(
            ch_xenium_output,
            rangerInput.transcripts,
            rangerInput.polygons
        )
}
