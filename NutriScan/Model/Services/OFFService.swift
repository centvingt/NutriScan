//
//  OFFService.swift
//  NutriScan
//
//  Created by Vincent Caronnet on 27/12/2020.
//

import Foundation

protocol OFFServiceProtocol {
    func getProduct(
        from eanCode: String,
        completion: @escaping (Result<NUProduct, OFFService.OFFError>) -> Void
    )
    func cancelRequest(with eanCode: String)
}

struct OFFService: OFFServiceProtocol {
    private var offApi:String
    
    // For unit tests
    private(set) var session = URLSession(configuration: .default)
    private var task: URLSessionDataTask?
    init(
        session: URLSession = URLSession.shared,
        offApi: String = "https://world.openfoodfacts.org/api/v0/products/"
    ) {
        self.session = session
        self.offApi = offApi
    }
    
    enum OFFError: Error {
        case connection,
             undefined,
             response,
             statusCode,
             data,
             noProductFound,
             cancelledRequest
    }
    
    func getProduct(
        from eanCode: String,
        completion: @escaping (Result<NUProduct, OFFError>) -> Void
    ) {
        // TODO: Utiliser ici URLComponent
        guard let productURL = URL(string: offApi + eanCode)
        else {
            print("OFFSERVICE ~> BAD URL")
            completion(.failure(.undefined))
            return
        }

        task?.cancel()
        let task = session.dataTask(with: productURL) { data, response, error in
            DispatchQueue.main.async {
                // HTTP request error handling
                if let error = error as? URLError {
                    if error.code == URLError.Code.notConnectedToInternet {
                        print("OFFSERVICE ~> ERROR BECAUSE NOT CONNECTED TO INTERNET")
                        completion(.failure(.connection))
                        return
                    } else if error.code == URLError.Code.cancelled {
                        print("OFFSERVICE ~> CANCELLED REQUEST")
                        completion(.failure(.cancelledRequest))
                        return
                    } else {
                       print("OFFSERVICE ~> UNDEFINED REQUEST ERROR ~>", error)
                       completion(.failure(.undefined))
                       return
                   }
                }
                
                // Getting HTTP response
                guard let response = response as? HTTPURLResponse else {
                    print("OFFSERVICE ~> ERROR WITH THE RESPONSE")
                    completion(.failure(.response))
                    return
                }
                guard response.statusCode == 200 else {
                    print("OFFSERVICE ~> ERROR WITH THE RESPONSE'S STATUS CODE", response.statusCode)
                    completion(.failure(.statusCode))
                    return
                }
                
                // Getting and decoding response's JSON data
                guard let data = data,
                      let offData = try? JSONDecoder().decode(OFFData.self, from: data)
                else {
                    print("OFFSERVICE ~> ERROR WITH THE DATA")
                    completion(.failure(.data))
                    return
                }

                // Checking than the response provide a product
                guard offData.status == 1,
                      let offProduct = offData.product
                else {
                    print("OFFSERVICE ~> NO PRODUCT FOUND")
                    completion(.failure(.noProductFound))
                    return
                }

                // Constructing a NUProduct's instance
                let id = offProduct._id
                
                let name = offProduct.product_name_fr ?? offProduct.product_name
                
                let nutriments = offProduct.nutriments

                let novaGroup = offProduct.nova_group
                
                var nutriScore: NutriScore?

                if let offNutriScore = offProduct.nutriscore_data,
                   let _ = offNutriScore.score,
                   let _ = offNutriScore.negative_points,
                   let _ = offNutriScore.positive_points,
                   let _ = offNutriScore.grade
                {
                    nutriScore = offNutriScore
                }
                
                let image_url = offProduct.image_url ?? nil

                var ecoScore: EcoScore?
                
                if let offEcoScore = offProduct.ecoscore_data,
                   let _ = offEcoScore.score,
                   let _ = offEcoScore.grade,
                   let offAgribalyse = offEcoScore.agribalyse,
                   let _ = offAgribalyse.score,
                   let _ = offEcoScore.adjustments
                {
                    ecoScore = offEcoScore
                }
                

                let product = NUProduct(
                    id: id,
                    name: name,
                    imageURL: image_url,
                    nutriments: nutriments,
                    nutriScore: nutriScore,
                    novaGroup: novaGroup,
                    ecoScore: ecoScore
                )
                
                // Return the NUProduct
                completion(.success(product))
            }
        }
        task.resume()
    }
    
    func cancelRequest(with eanCode: String) {
        guard let url = URL(string: offApi + eanCode)
        else { return }
        
        session.getAllTasks { tasks in
          tasks
            .filter { $0.state == .running }
            .filter { $0.originalRequest?.url == url }
            .first?
            .cancel()
        }
      }
}
