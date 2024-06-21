    // Reading input files
    Eigen::MatrixXd inxyz = read_matrix(xyzname);
    Eigen::MatrixXd indat = read_matrix(datname);
    
    int izl = inxyz.rows();
    int itl = indat.rows();
    
    const int CELL_NUM = 320;
    const int CENTER_INDEX = 256;
    const int SECTION_NUM = 99 * (4 - 1) + 1; // = 298
    const int XYZVEC_STARTNUM = 4;
    const int POINT_SIZE = 3;

    Eigen::Vector3d inlet = read_inlet(inlname);

    // Initializing new data matrix
    Eigen::MatrixXd newdat = Eigen::MatrixXd::Zero(itl, 7 + 3 + 3 + 1 + 1 + 1);

    // Start time
    std::clock_t stime = std::clock();
//    auto stime = std::chrono::high_resolution_clock::now();

    // Get center points from xyzout
    Eigen::MatrixXd center_point_seq(SECTION_NUM, 3);
    int count = -1;
    int rawcount = -1;

    for (int i = 0; i < izl; ++i) {
        if (i % CELL_NUM == CENTER_INDEX) {
            rawcount++;
            if (rawcount != 0 && rawcount % 4 == 0) {
                continue;
            }
            count++;
            if (count < SECTION_NUM) {
                center_point_seq.row(count) = inxyz.row(i);
            }
        }
    }
    int cntl = center_point_seq.rows();

    // Check the start position
    double dis1 = (inlet.transpose() - center_point_seq.row(0)).norm();
    double dis2 = (inlet.transpose() - center_point_seq.row(SECTION_NUM - 1)).norm();
    int flow_direction = (dis1 >= dis2) ? -1 : 1;

    // Iterating over rows in indat
    for (int enumerate_i = 0; enumerate_i < std::min(9999999,itl); ++enumerate_i) {
        if (enumerate_i % 9999 == 0) {
            std::cout << enumerate_i << " /" << itl << " :" << (std::clock() - stime) / (double)CLOCKS_PER_SEC << " sec" << std::endl;
        }
        Eigen::Vector3d xyz = indat.row(enumerate_i).head<3>();
//        std::cout << xyz << " points" << std::endl;
//        Eigen::RowVectorXd first_row = center_point_seq.row(0);
//        Eigen::RowVectorXd last_row = center_point_seq.row(SECTION_NUM - 1);
//        std::cout << center_point_seq.rows() << " center points" << std::endl;
//        std::cout << first_row << " first center points" << std::endl;
//        std::cout << inlet << " inlet center points" << std::endl;
//
//        std::cout << flow_direction << " flow direction" << std::endl;
        
        // Get center position: get center_box and box_direction
//        double distm1 = 888;
        double dist0 = 999;
//        double distp1 = 0;
        int cent0 = 0;
        for (int i = 0; i < cntl; ++i) {
            double dist = (xyz.transpose() - center_point_seq.row(i)).norm();
            if (dist0 >= dist) {
                //                distm1 = dist0;
                dist0 = dist;
                cent0 = i;
            }
        }
//            } else {
//                distp1 = dist;
//                break;
//            }
//        }

        double position;
        int box_direction;
        if (cent0 == 0) {
            box_direction = 1;
            double distp1 = (xyz.transpose() - center_point_seq.row(cent0+1)).norm();
            position = dist0 / (dist0 + distp1);
        } else if (cent0 == cntl-1) {
            box_direction = -1;
            double distm1 = (xyz.transpose() - center_point_seq.row(cent0-1)).norm();
            position = -dist0 / (dist0 + distm1);
        } else {
            double distm1 = (xyz.transpose() - center_point_seq.row(cent0-1)).norm();
            double distp1 = (xyz.transpose() - center_point_seq.row(cent0+1)).norm();
            if (std::abs(dist0 - distm1) <= std::abs(dist0 - distp1)) {
                position = -dist0 / (dist0 + distm1);
                box_direction = -1;
            } else {
                position = dist0 / (dist0 + distp1);
                box_direction = 1;
            }
        }

        std::vector<double> centbox = {static_cast<double>(cent0), position};
//        std::vector<double> centbox = {static_cast<double>(cent0), static_cast<double>(cent0 - 1), static_cast<double>(cent0 + 1), dist0, distm1, distp1, position};

//        std::cout << centbox[0] << " center box" << std::endl;
        
        // B-1. Check duplicate points in CELL_NUM for each section
        int ci = static_cast<int>(centbox[0]);
        int newci;
        if (ci == 0) {
            newci = 0;
        } else {
            int ci_resd = (ci - 1) % 3 + 1;
            int ci_mod = (ci - 1) / 3;
            newci = ci_mod * 4 + ci_resd;
        }

        Eigen::MatrixXd fibre_section = inxyz.block(newci * CELL_NUM, 0, CELL_NUM, 3);
        int fibl = fibre_section.rows();
        int s0 = newci * CELL_NUM;
//        int fsamecount = 0;
//        std::vector<std::vector<int>> fsamelist;
        std::vector<int> fdifflist;

        // Checking unique points on the section for fibres
        for (int i = 0; i < fibl - 1; ++i) {
            bool breakpp = false;
            for (int j = i + 1; j < fibl; ++j) {
                bool breakpoint = false;
                for (int k = 0; k < 3; ++k) {
                    if (inxyz(s0 + i, k) != inxyz(s0 + j, k)) {
                        breakpoint = true;
                        break;
                    }
                }
                if (!breakpoint) {
//                    fsamecount++;
//                    if (std::find(fsamelist.begin(), fsamelist.end(), std::vector<int>{i, j}) == fsamelist.end()) {
//                        fsamelist.push_back({i, j});
//                    }
                    breakpp = true;
                    break;
                }
            }
            if (!breakpp) {
                if (std::find(fdifflist.begin(), fdifflist.end(), i) == fdifflist.end()) {
                    fdifflist.push_back(i);
                }
            }
        }

        if (std::find(fdifflist.begin(), fdifflist.end(), fibl - 1) == fdifflist.end()) {
            fdifflist.push_back(fibl - 1);
        }
        
        // Print the fdifflist
//        std::cout << "fdifflist: ";
//        for (const int& item : fdifflist) {
//            std::cout << item << " fd item ";
//        }
//        std::cout << std::endl;
        
        // B-2. Find 4 fibre points on the section of the cent0
        std::vector<std::pair<double, int>> sortf;
        for (int i : fdifflist) {
            double dist = (xyz.transpose() - fibre_section.row(i)).norm();
            sortf.push_back({dist, i});
        }

        // Sort by distance
        std::sort(sortf.begin(), sortf.end());

        // Store the closest 4 points
        std::vector<std::vector<double>> fibre_box;
        for (int i = 0; i < std::min(4, (int)sortf.size()); ++i) {
            int fi = sortf[i].second;
            std::vector<double> entry = {static_cast<double>(ci), sortf[i].first, static_cast<double>(fi)};
            for (int j = 0; j < 3; ++j) {
                entry.push_back(fibre_section(fi, j));
            }
            fibre_box.push_back(entry);
        }

//        // Print the fibre_box
//        std::cout << "fibre_box: " << std::endl;
//        for (const auto& row : fibre_box) {
//            for (const auto& elem : row) {
//                std::cout << elem << " fibre item";
//            }
//            std::cout << std::endl;
//        }
        
        // Calculate the next fibre box, called f2ibre_box
        int ci2 = static_cast<int>(centbox[0]) + box_direction;
        int ci2_resd = (ci2 - 1) % 3 + 1;
        int ci2_mod = (ci2 - 1) / 3;
        int newci2 = ci2_mod * 4 + ci2_resd;
        Eigen::MatrixXd f2ibre_section = inxyz.block(newci2 * CELL_NUM, 0, CELL_NUM, 3);
        std::vector<std::vector<double>> f2ibre_box;
        for (const auto& fb : fibre_box) {
            int fi = static_cast<int>(fb[2]); // get fi from the first fibre_box
            Eigen::Vector3d f2s_xyz = f2ibre_section.row(fi);
            double di2 = (xyz - f2s_xyz).norm();
            f2ibre_box.push_back({static_cast<double>(ci2), di2, static_cast<double>(fi), f2s_xyz[0], f2s_xyz[1], f2s_xyz[2]});
        }
        // Print the f2ibre_box
//        std::cout << "f2ibre_box: " << std::endl;
//        for (const auto& row : f2ibre_box) {
//            for (const auto& elem : row) {
//                std::cout << elem << " f2ibre item";
//            }
//            std::cout << std::endl;
//        }
        
        std::vector<std::vector<double>> first_box;
        std::vector<std::vector<double>> second_box;
        int THIRD_SEC = 0;

        if (flow_direction == 1 && box_direction == 1) {
            // Scatch: f2ibre_box[ci+1] - fibre_box[ci]
            // Scatch: f3ibre_box[ci+2] - f2ibre_box[ci+1]
            first_box = fibre_box;
            second_box = f2ibre_box;
            THIRD_SEC = 2; // This is for 3rd section
        } else if (flow_direction == 1 && box_direction == -1) {
            // Scatch: fibre_box[ci] - f2ibre_box[ci-1]
            // Scatch: f3ibre_box[ci+1] - fibre_box[ci]
            first_box = f2ibre_box;
            second_box = fibre_box;
            THIRD_SEC = 1; // This is for 3rd section
        } else if (flow_direction == -1 && box_direction == 1) {
            // Scatch: fibre_box[ci] - f2ibre_box[ci+1]
            // Scatch: f3ibre_box[ci-1] - fibre_box[ci]
            first_box = f2ibre_box;
            second_box = fibre_box;
            THIRD_SEC = -1; // This is for 3rd section
        } else if (flow_direction == -1 && box_direction == -1) {
            // Scatch: f2ibre_box[ci-1] - fibre_box[ci]
            // Scatch: f3ibre_box[ci-2] - f2ibre_box[ci-1]
            first_box = fibre_box;
            second_box = f2ibre_box;
            THIRD_SEC = -2; // This is for 3rd section
        } else {
            std::cout << "ERROR: check flow_direction and box_direction." << std::endl;
        }
        
//        std::cout << THIRD_SEC << " 3rd section const" << std::endl;
        
        // Compute ci3 and newci3
        int ci3 = static_cast<int>(fibre_box[0][0]) + THIRD_SEC;
        if (ci3 == -1) {
            ci3 = 0;
        } else if (ci3 == cntl) {
            ci3 = cntl - 1;
        }
        int ci3_resd = (ci3 - 1) % 3 + 1;
        int ci3_mod = (ci3 - 1) / 3;
        int newci3 = ci3_mod * 4 + ci3_resd;
        
//        std::cout << ci << " " << ci2 << " " << ci3 << " " << center_point_seq.rows() << std::endl;
//        std::cout << newci << " " << newci2 << " " << newci3 << " " << center_point_seq.rows() << std::endl;
        // Extract the section of inxyz corresponding to newci3
        Eigen::MatrixXd f3ibre_section = inxyz.block(newci3 * CELL_NUM, 0, CELL_NUM, 3);

        // Compute f3ibre_box
        std::vector<std::vector<double>> f3ibre_box;
        for (const auto& fb : fibre_box) {
            int fi = static_cast<int>(fb[2]); // get fi from the first fibre_box
            Eigen::Vector3d f3s_xyz = f3ibre_section.row(fi);
            double di3 = (xyz - f3s_xyz).norm();
            f3ibre_box.push_back({static_cast<double>(ci3), di3, static_cast<double>(fi), f3s_xyz[0], f3s_xyz[1], f3s_xyz[2]});
        }
        // Print the f3ibre_box
//        std::cout << "f3ibre_box: " << std::endl;
//        for (const auto& row : f3ibre_box) {
//            for (const auto& elem : row) {
//                std::cout << elem << " f3ibre item";
//            }
//            std::cout << std::endl;
//        }

        // Define vectors to store groundVecSec1 and groundVecSec2
        std::vector<std::vector<double>> groundVecSec1;
        std::vector<std::vector<double>> groundVecSec2;

//         Iterate over the vectors first_box, second_box, and f3ibre_box
        for (size_t i = 0; i < first_box.size(); ++i) {
            // Calculate ground vectors for the first and second sections
            std::vector<double> groundVec1 = {first_box[i][1], second_box[i][3] - first_box[i][3]};
            std::vector<double> groundVec2 = {second_box[i][1], f3ibre_box[i][3] - second_box[i][3]};
            
            // Store the ground vectors for the first and second sections
            groundVecSec1.push_back(groundVec1);
            groundVecSec2.push_back(groundVec2);
        }

        // Concatenate ground vectors from both sections
        std::vector<std::vector<double>> ground8Vec = groundVecSec1;
        ground8Vec.insert(ground8Vec.end(), groundVecSec2.begin(), groundVecSec2.end());

        // Compute the sum of the distances
        double sumd = 0.0;
        for (const auto& x : ground8Vec) {
            sumd += x[0];
        }

        // Compute the ground vector
        Eigen::Vector3d groundvec(0.0, 0.0, 0.0);
        for (const auto& x : ground8Vec) {
            double const_val = 1.0 / x[0];
            groundvec += const_val * Eigen::Vector3d(x[1], x[2], x[3]);
        }

        // Normalize the ground vector
        Eigen::Vector3d groundvecnormal = groundvec.normalized();

        // Retrieve xyzvec
        Eigen::VectorXd xyzvec = indat.row(enumerate_i).segment(XYZVEC_STARTNUM, POINT_SIZE);
//        std::cout << "xyzvec: " << xyzvec.transpose() << std::endl;

        // Compute rotation matrix
        Eigen::Matrix3d mat = rotation_matrix_from_vectors(groundvecnormal);

        // Rotate xyzvec
        Eigen::VectorXd xyzvec_rot = mat * xyzvec;

        // Compute spherical vector
        Eigen::Vector3d sphvec = xyzvec_rot.normalized();

        // Compute center percentile
        double centile = (centbox[0] + centbox[6]) * flow_direction;

        // Compute angle between ground vector and xyzvec
        double ag = std::acos(groundvec.dot(xyzvec) / (groundvec.norm() * xyzvec.norm()));
//
        Eigen::VectorXd xyzall = indat.row(enumerate_i);
        // Concatenate all the required data
        Eigen::VectorXd save(7 + 3 + 3 + 1 + 1 + 1);
        save << xyzall[0], xyzall[1], xyzall[2], xyzall[3], xyzall[4], xyzall[5], xyzall[6], sphvec[0], sphvec[1], sphvec[2], groundvecnormal[0], groundvecnormal[1], groundvecnormal[2], ag, static_cast<double>(enumerate_i), centile;

        // Store the data in newdat
        newdat.row(enumerate_i) = save;
    }
    
    try {
        // Stop the timer and print elapsed time
//        auto etime = std::chrono::high_resolution_clock::now();
//        std::chrono::duration<double> elapsed = etime - stime;
//        std::cout << elapsed.count() << " seconds: newdat done. saving..\n";
        std::cout << (std::clock() - stime) / (double)CLOCKS_PER_SEC << " seconds: newdat done. saving.." << std::endl;
        // Save newdat
        save_matrix(datname + "_new_june21", newdat);

//        etime = std::chrono::high_resolution_clock::now();
//        elapsed = etime - stime;
//        std::cout << elapsed.count() << " seconds: saved. now sorting..\n";
        std::cout << (std::clock() - stime) / (double)CLOCKS_PER_SEC << " seconds: saved. now sorting.." << std::endl;

        // Sort newdat based on the last column
        Eigen::MatrixXd sorted_newdat = newdat;
        std::vector<size_t> indices(sorted_newdat.rows());
        std::iota(indices.begin(), indices.end(), 0);

        std::sort(indices.begin(), indices.end(),
                  [&sorted_newdat](size_t i1, size_t i2) {
                      return sorted_newdat(i1, sorted_newdat.cols() - 1) < sorted_newdat(i2, sorted_newdat.cols() - 1);
                  });

        for (size_t i = 0; i < indices.size(); ++i) {
            sorted_newdat.row(i) = newdat.row(indices[i]);
        }

//        etime = std::chrono::high_resolution_clock::now();
//        elapsed = etime - stime;
//        std::cout << elapsed.count() << " seconds: sorted. now saving..\n";
        std::cout << (std::clock() - stime) / (double)CLOCKS_PER_SEC << " seconds: sorted. now saving.." << std::endl;

        // Save sorted_newdat
        save_matrix(datname + "_sorted_june21", sorted_newdat);

//        etime = std::chrono::high_resolution_clock::now();
//        elapsed = etime - stime;
//        std::cout << elapsed.count() << " seconds: DONE.\n";
        std::cout << (std::clock() - stime) / (double)CLOCKS_PER_SEC << " seconds: DONE." << std::endl;

    } catch (const std::exception& e) {
        std::cerr << "Exception: " << e.what() << std::endl;
        return 1;
    }
    return 0;
}
