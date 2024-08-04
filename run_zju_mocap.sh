#bash run_zju_mocap.sh
seq=my_394
dataset_name=zju_mocap
view=/05/ #choose a front view
front_view=92
dataset_type=$(echo $dataset_name | awk -F"_" '{print $1}')
gender=male
decoupling=True

if [ -z "$(ls -A "data/${dataset_name}/${seq}/images")" ]
then
    echo "please download ${dataset_name} dataset. if you run the people_snapshot, please use instantavatar to generate the images"
    exit 0
fi
#===========run the Self-Correction-Human-Parsing-master======
if [ -z "$(ls -A "data/${dataset_name}/${seq}/schp")" ]
then
    echo "doing schp(only for people_snapshot dattaset)"
    #mkdir -p data/${dataset_name}/${seq}/schp
    python read_image_name.py --folder_path data/${dataset_name}/${seq}/images --output_path data/${dataset_name}/${seq}/images.txt
    cd submodules/Self-Correction-Human-Parsing-master
    echo "warning!!! go to make global_local_evaluate.py saving pth useless"
    python mhp_extension/global_local_parsing/global_local_evaluate.py --data-dir ../../data/${dataset_name}/${seq}/ --split-name images --model-restore mhp_extension/pretrain_model/exp_schp_multi_cihp_global.pth --log-dir ../../data/${dataset_name}/${seq}/ --save-results
    #python simple_extractor.py --input-dir ../../data/${dataset_name}/${seq}/images --output-dir ../../data/${dataset_name}/${seq}/schp #--model-restore ./pretrain_model/resnet101-imagenet.pth
    #mv 
    cd ../
    cd ../
    mv data/${dataset_name}/${seq}/images_parsing data/${dataset_name}/${seq}/schp
fi
#===========run the frankmocap======================
if [ -z "$(ls -A "data/${dataset_name}/${seq}/mocap_input/mocap")" ]
then
    echo "doing mocap"
    mkdir -p data/${dataset_name}/${seq}/mocap_input
    cd submodules/frankmocap-main
    timeout 45 python -m demo.demo_bodymocap --input_path ../../data/${dataset_name}/${seq}/images${view} --out_dir ../../data/${dataset_name}/${seq}/mocap_input --save_pred_pkl
    cd ../
    cd ../
fi
#==========GT segmentation==========================
if [ -z "$(ls -A "data/${dataset_name}/${seq}/cloth_segmentation/tee/")" ]
then
    echo "doing cloth segmentation"
    mkdir -p "data/${dataset_name}/${seq}/cloth_segmentation"
    python seg_image.py --task_root data/${dataset_name}/${seq} --mask_root schp${view} --input_name images${view}
fi
#=========cloth initalization========================
if [ -z "$(ls -A "data/${dataset_name}/${seq}/cloth_model")" ]
then
    echo "doing cloth initalization and it may spend a long time"
    cd lib_isp
    python fitting_image.py --save_root data/${dataset_name}/${seq} --mask_root schp${view} --front_view $front_view
    cd ..
    mv lib_isp/skin_weights.pkl "data/${dataset_name}/${seq}/cloth_model/"
    mkdir -p "data/${dataset_name}/${seq}/cloth_model"
    python cloth_init.py --cloth_root data/${dataset_name}/${seq}/cloth_model/ --gender $gender --decoupling $decoupling
fi
#===========main function======================================
python solver.py --profile ./profiles/${dataset_type}/${dataset_type}_default.yaml --dataset $dataset_name --seq $seq --logbase ${dataset_type}_default --fast --no_eval --decoupling $decoupling --garment_init