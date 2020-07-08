# # # CALCS function, for ccspectral
# vis.files = vis_files
# nir.files = nir_files
# manual.mask.test = manual.mask.test
# mask.files = mask_files
# summary.file = summary_file
# total.samples = total_samples
# index.= index.
# descriptors.= descriptors.
# calculate.thresh = calculate.thresh
# threshold.method = threshold.method
# area <- 3
# photo <- 3

calcs <- function(photo,
                  area, 
                  obs.areas, 
                  vis.files,
                  nir.files,
                  manual.mask.test,
                  mask.files, 
                  summary.file,
                  chart,
                  total.samples, 
                  index., 
                  descriptors., 
                  calculate.thresh, 
                  thereshold.vector,
                  descrip,
                  threshold.method,
                  pdf) {
  # Prepare data
  obs_area   <- obs.areas[[area]]
  vis_photo  <- vis.files[photo]
  nir_photo  <- nir.files[photo]
  if(manual.mask.test==T){
    mask_photo <- mask.files[photo]
    }
  
  
  
  # Select and set sample name 
  
  done_samples <-
    nrow(data.table::fread(summary.file, select = 1L, header = T))
  if (file.exists("names.csv")) { sample_names <- c(as.character(read.csv("names.csv")[, 1]))
  if (length(sample_names) != total.samples) 
    {stop ("File of sample names contains less/more names than samples")}
  } else{
    sample_names <- c(names = paste0("obs_", 1:(total.samples)))
  }
  # set sample name
  # if (done_samples > 0) { 
  #   sample_name <- sample_names[done_samples + 1]
  # }else{
  #   sample_name <- sample_names[1]}
  
  sample_name <- sample_names[photo]
  
  # Check all single elements have been correctly set ===========================

  print(vis_photo)
  print(nir_photo)
  print(paste0(names(obs.areas)[area], ": ", sample_name))
  if(manual.mask.test==T){
  print(mask_photo)
  }
  # Cell extraction and color calibration -----------------------------------------------------
  # Read and create raster from tiff =====================================
  # source("./ccspectral/raster.tif.ccspectral.R")
  
  if(manual.mask.test==T){
    all_bands <-  raster.tiff.ccspectral(vis.photo = vis_photo, nir.photo = nir_photo, 
                                         manual.mask.test = manual.mask.test, 
                                         mask.photo = mask_photo)
  }else{
    all_bands <-  raster.tiff.ccspectral(vis.photo = vis_photo, nir.photo = nir_photo, 
                                         manual.mask.test = manual.mask.test)
  }
  
  
  
   
  # ######IF ML
    # source("./ccspectral/cell.extract.color.cal.fun.R")
  
  calibration_results <-
    cell.extract.color.cal.fun(
      obs.area = obs_area,
      all.bands = all_bands,
      chart = chart,
      manual.mask.test = manual.mask.test,
      pdf = pdf
    )
  
 # if(descrip==T){
 #  red_rsq <- calibration_results[3]
 #  green_rsq <- calibration_results[4]
 #  blue_rsq <- calibration_results[5]
 #  nir_rsq <- calibration_results[6]
 #  if(manual.mask.test==T){
 #  real_cover_moss <- sum(getValues(calibration_results[[2]][[4]]))
 #  }
 #  }else{
    # if(manual.mask.test==T){
    #   real_cover_moss <- sum(getValues(calibration_results[[2]][[4]]))
    #   }
    # }
  if(pdf==T && manual.mask.test==T){
    moss_poly <- calibration_results[7]
    }
  ###########################################################################  
  # Calculate index values, as raster and as dataframe ----------------------
  ############################################################################  

    # source("./ccspectral/indexcalculation.fun.R")
  
  list_raster_results <- index.calc.fun(raster.mat  = calibration_results[[1]], 
                                       raster.band = calibration_results[[2]] , 
                                       index. = index.
                                       # calculate.thresh=calculate.thresh, 
                                       # threshold.vector,
                                       # calculate.thresh = calculate.thresh,
                                       # manual.mask.test = manual.mask.test,
                                       # threshold.method = threshold.method,
                                       # pdf = pdf
                                      )
  
  # Calculate thershold results
  
  # if(calculate.thresh == TRUE) {
    # source("./ccspectral/autothreshold.value.func.R")}
    
    # source("./ccspectral/calculate.raster.thresh.fun.R")
    
    
    list_threshold_results <-
      calculate.raster.thresh.fun(
        list.raster.results = list_raster_results,
        calculate.thresh    = calculate.thresh,
        threshold.method    = threshold.method,
        threshold.vector    = threshold.vector
        )
  # Extract mask values -----------------------------------------------------
  #extract mask pixel coordinates
  if(manual.mask.test==T){
    # Set df list with cell coordinates(x,y) indexvalues(z) 
    # mask threshold(surface) and mask manual(surface)
    # Aditionnaly we need to compare manual segmentation and threshold segmentation
     # we create new surface classes (as new cols in the data frame )
    # by crossing the two classification as follows:
    # b_as_b => real (manual) background classified as background (by threshold classification) )
    # m_as_b => real (manual) background classified as moss (by threshold classification)
    # b_as_m => real (manual) moss classified as background (by threshold classification)
    # m_as_m => real (manual) moss classified as moss (by threshold classification)
    coor <- 
      coordinates(calibration_results[[1]])
    surface_class <-
      lapply(1:length(list_raster_results),
             function(i)
               paste0(getValues(list_threshold_results[[1]][[i]]),
                      getValues(calibration_results[[2]][[4]])
                      )
             )
    if(require(varhandle)!=T){
    install.packages("varhandle")
    require(varhandle)}
    binary_surfaces <- 
      lapply(1:length(surface_class),
             function(i)
               varhandle::to.dummy(surface_class[[i]], "surface")
             )
    list_df_results <-
      lapply(c(1:length(list_raster_results)),
             function(i)
               cbind(
                 coor,
                 getValues(list_raster_results[[i]]),
                 getValues(list_threshold_results[[1]][[i]]),
                 getValues(calibration_results[[2]][[4]]),
                 binary_surfaces[[i]][,1],
                 binary_surfaces[[i]][,2],
                 binary_surfaces[[i]][,3],
                 binary_surfaces[[i]][,4]
                 )
             )
    # transform in data frame
    list_df_results <-
      lapply(c(1:length(list_raster_results)), function(i)
        as.data.frame(list_df_results[[i]]))
    
    # Set colnames
    colnames <- c("x", "y", "index_value", "surface_threshold", "surface_manual", 
                  "b_as_b", "m_as_b", "b_as_m", "m_as_m")
    
    list_df_results <- lapply(list_df_results, setNames, colnames)
    rm(colnames, surface_class, binary_surfaces)
    }else{ 
    coor <- coordinates(calibration_results[[1]])
    # Set df list with cell coordinates(x,y) indexvalues(z)  and 
    # mask threshold values (surface)
    list_df_results <-
      lapply(c(1:length(list_raster_results)),
             function(i)
               cbind(
                 coor,
                 getValues(list_raster_results[[i]]),
                 getValues(list_threshold_results[[1]][[i]])
                 )
             )
    # transform in data frame
    list_df_results <-
      lapply(c(1:length(list_raster_results)), function(i)
        as.data.frame(list_df_results[[i]]))
    # Set colnames
    colnames <- c("x", "y", "index_value", "surface_threshold")
    list_df_results <- lapply(list_df_results, setNames, colnames)
    names(list_df_results) <- names(list_raster_results)
    rm(colnames)
    }
  
  if(pdf == FALSE){
    rm(list_raster_results)
    list.results<- list(list_df_results)
    names(list.results) <- c("data.frames")
  }else{
    # List raster results an df results
    list.results <- list(list_df_results, list_raster_results)
    names(list.results) <- c("data.frames", "rasters")}
  # Return
  
  # return(list.results)
  
  
  rm(calibration_results)
  ############################################################################  
  # Descriptors calculation -------------------------------------------------
  ############################################################################
  if(descrip==F){
    if(manual.mask.test==F){
      int_surf_cover <-
        do.call(c,
                lapply(c(1:length(index.)),
                       function(i)
                         unname(
                           c(
                             table(list.results[[1]][[i]][,4])[2], table(list.results[[1]][[i]][,4])[1]
                           )
                         )
                )
        )
  }else{
    int_surf_cover <-
      do.call(c,
              lapply(c(1:length(index.)),
                     function(i)
                       unname(
                         c(
                           table(list.results[[1]][[i]][,4])[2], table(list.results[[1]][[i]][,4])[1],
                           table(list.results[[1]][[i]][,5])[2], table(list.results[[1]][[i]][,5])[1],
                           table(list.results[[1]][[i]][,4])[2], table(list.results[[1]][[i]][,4])[1],
                           table(list.results[[1]][[i]][,5])[2], table(list.results[[1]][[i]][,5])[1],
                           table(list.results[[1]][[i]][,6])[2], table(list.results[[1]][[i]][,6])[1],
                           table(list.results[[1]][[i]][,7])[2], table(list.results[[1]][[i]][,7])[1],
                           table(list.results[[1]][[i]][,8])[2], table(list.results[[1]][[i]][,8])[1],
                           table(list.results[[1]][[i]][,9])[2], table(list.results[[1]][[i]][,9])[1]
                         )
                       )
              )
      )
    }
  }else{#descrip==T
    # source("./ccspectral/Descriptor.calculation.fun.R")
    if(manual.mask.test==F){
      int_surf_cover <-
        do.call(c,
                lapply(c(1:length(index.)),
                       function(i)
                         do.call(c,
                                 lapply( 0:1 , function(j)
                                   descriptor.fun(
                                     list.results[[1]][[i]][,3][list.results[[1]][[i]][,4] == j],
                                     descriptors.)
                                   )
                                 )
                       )
                )
      }else{#manual.mask.test==T
        
        int_surf_cover <-
        
                  lapply(c(1:length(index.)),
                         function(i)
                           do.call(c,
                                   lapply(4:5 , function(j)
                                     do.call(c,
                                             lapply(0:1, function(k)
                                               descriptor.fun(
                                                 list.results[[1]][[i]][,3][list.results[[1]][[i]][,j] == k],
                                                 descriptors.)
                                               )
                                             )
                                     )
                                   )
                         )
        test_mask_surfaces <-   
          lapply(c(1:length(index.)),
                 function(i)
                   do.call(c,
                           lapply(6:9 , function(j)
                             descriptor.fun(
                               list.results[[1]][[i]][,3][list.results[[1]][[i]][,j] == 1],
                               descriptors.)
                             )
                           )
                 )
        int_surf_cover <-
          do.call(c,
                  lapply(c(1:length(index.)),
                         function(i)
                           c(int_surf_cover[[i]], test_mask_surfaces[[i]]
                             )
                         )
                  )
        rm(test_mask_surfaces)      
                         
      }
    }
   

  # START dataframe for index index vaulues presentation --------------------
  
  dat <- read.csv(summary.file)
  
  # names(descriptor_value) <- colnames(dat)[-c(1:7)]
  # 
  if(calculate.thresh==T){
    new_dat <-
      as.data.frame(
        as.list(
          c(
            sample_name,
            vis_photo,
            nir_photo,
            unname(int_surf_cover),
            unname(do.call(c,list_threshold_results[[2]])),
            threshold.method
            )
          )
        )
  }else{
    new_dat <-
      as.data.frame(
        as.list(
          c(
            sample_name,
            vis_photo,
            nir_photo,
            unname(int_surf_cover),
            threshold.vector,
            "Predefined"
          )
        )
      )
    }

  colnames(new_dat) <- colnames(dat)
  dat_bind <- rbind(dat, new_dat)
  write.csv(dat_bind, summary.file, row.names = F)
  
  # Create pdf to plot results ---------------------------------------------
  if(pdf == T){
    # Set plotpdf function to plot results (operated by lists) ---------------------------------
    pdf_name <- paste0(out_dir, "/", sample_name, ".pdf")
    
    plotpdf <-  function(lhist, lind, lman, lover, i.names, asp, pdf.name){
      # set pdf structure -------------------------------------------------------
     
      pdf(file = pdf.name, w = 14, h = 3.571429 * length(index.))
      par(mfrow = c(length(index.), 4))
      
      # set function for pdf graphic content ------------------------------------
      # hist:raster dataframe with x y coordinates index value (z) and binary mask value (surface)
      # ind: index raster
      
      pdfprint <-   function(hist, ind, man, over, name, asp){
        # set surface binary image as factor ------------------------------------
      
        surface.f <- factor(hist[,4], levels= c(1,0),
                            labels = c("no_moss","moss"))
        # surface.overlap <- factor(hist[,5], levels= c(1,2,3),
        #                     labels = c("substrate","overlap","moss"))
        #
        # PLOT densities ----------------------------------------------------------
        if(require(sm)!=T){
          install.packages("sm")
        }
        sm::sm.density.compare(hist[,3], surface.f, xlab= name)
        
        title(main = paste(names), "values by surface")
        # add legend
        colfill <- c(2:(2+length(levels(surface.f))))
        legend("topright", levels(surface.f), fill=colfill)
        
        # PLOT index values and real moss contour --------------------------------
        plot(ind,
             # main =  paste(toupper(names)),"values",
             axes = FALSE, box = FALSE,
             asp  = asp)
        plot(moss_poly, add=T, border="red")
        
        # PLOT index values from real moss area and real moss contour  ------------
        plot(man,
             main =  paste(toupper(name)),"moss values over whole scene",
             axes = FALSE, box = FALSE,
             asp  = asp)
        plot(moss_poly, add=T, border="red")
        
        # PLOT overlap index values between real moss area and background  ------------
        plot(over,
             main =  paste(toupper(names)),"index overlap regions",
             axes = FALSE, box = FALSE,
             asp  = asp)
        plot(moss_poly, add=T, border="red")
        
      }
      # run pdf.print over our list of indexes ----------------------------------
      lapply(c(1:length(lind)), function(i)
        pdfprint(hist  = list_df_results[[i]][,3],
                 ind   = lind[[i]],
                 man   = lman[[i]],
                 over  = lover[[i]],
                 names = i.names[[i]],
                 asp   = asp))
      # close pdf ---------------------------------------------------------------
      dev.off()
    }
    
    # run plotpdf ------------------------------------------------------------------------------
    plotpdf(lhist   = lhist,
            lind    = index.,
            lman    =  moss_manual_int_list,
            lover   = overlap_index_list,
            i.names = index_names,
            asp     = asp,
            pdf.name = paste0(sample_name, ".pdf"))
  }
  
  loop_end_time <- Sys.time()
  loop_time <- difftime(loop_end_time, start_time, units = "secs" )
  
  message(paste0(sample_name, " processed... (",
                 100* round((done_samples+1)/total.samples, 2), " %). Expected end time:",
                 start_time+as.numeric(total.samples*loop_time/(done_samples+1))))
  
  # print = paste(sample_name, "processed")
}     