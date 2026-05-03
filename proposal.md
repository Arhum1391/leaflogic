Project Proposal: LeafLogic
AI-Powered Mobile Plant Disease Diagnostic System
________________________________________
Submitted by: 
Arhum Fareed (FA23-BAI-006)
Khair ul wara Hussain (FA23-BAI-022)
________________________________________
1. Introduction
In both domestic gardening and large-scale agriculture, the rapid identification of plant pathology is critical to crop survival. Traditional methods of diagnosis—relying on physical encyclopedias or waiting for human expert consultation—are often too slow to prevent the spread of pathogens.
LeafLogic is a mobile application developed using Flutter and Python-based Machine Learning to provide instantaneous, on-site disease diagnosis. By leveraging Convolutional Neural Networks (CNNs), the app allows users to photograph a distressed leaf and receive an immediate diagnosis, confidence rating, and organic treatment plan. This project aims to bridge the gap between complex botanical science and the everyday gardener.
2. Objectives
The primary goal of this project is to develop a functional, user-friendly mobile MVP (Minimum Viable Product) that achieves the following:
•	High Accuracy Identification: Achieve 80% + accuracy in detecting common diseases (e.g., Rust, Powdery Mildew, Blight) across at least five major plant species.
•	Educational Outreach: Provide actionable, environmentally friendly treatment advice rather than just a name for the disease.
•	History Tracking: Allow users to monitor the health of their plants over time through a persistent digital log.
3. System Features
•	Real-time Camera Scanner: An integrated Flutter camera module with an overlay guide to ensure optimal leaf positioning.
•	Diagnostic Dashboard: A clean UI displaying the identified plant species, the detected disease, and a "Confidence Score" (e.g., 94% Certainty).
•	Treatment Repository: A categorized database of organic and chemical treatments specifically mapped to detected diseases.
•	User History & Gallery: A localized or cloud-based storage system where users can view past scans to track if a treatment is working.
•	Offline Support: Leveraging TensorFlow Lite to allow basic diagnostic capabilities even in areas with poor cellular reception (like remote gardens).
________________________________________
4. Artificial Intelligence Components
The core intelligence of LeafLogic rests on two primary ML pillars:
Image Classification Model:
1.	Architecture: A MobileNetV2 or ResNet-50 architecture, pre-trained on ImageNet and fine-tuned on the PlantVillage dataset (containing 50,000+ images of healthy and infected leaves).
2.	Optimization: The model will be converted to .tflite format to reduce the footprint for mobile deployment.
________________________________________
5. Technical Stack
Layer	Technology
Frontend	Flutter (Dart) for Android/iOS deployment.
Backend API	FastAPI (Python) for high-performance asynchronous requests.
Machine Learning	TensorFlow / Keras for training; TFLite for mobile execution.
Image Processing	OpenCV for leaf segmentation and noise reduction.

________________________________________
6. Database Structure Overview	
We will utilize a hybrid storage approach:
•	Local Storage (SQLite): Stores the user’s recent scan history, plant nicknames, and offline-cached treatment tips.
•	Cloud Database (PostgreSQL/Firebase): Stores the comprehensive "Disease Encyclopedia," including high-resolution reference images and treatment protocols.
________________________________________


7. Expected Outcomes
Upon completion of the semester, the project will yield:
1.	A Cross-Platform App: A fully compiled .apk or .ipa file.
2.	A Trained Model: A specialized weights file capable of identifying at least 15 distinct plant-disease pairs.
3.	Comprehensive Documentation: A technical manual detailing the training hyper-parameters and the API documentation.
4.	User Impact: A tool that reduces the time-to-treatment for plant diseases by an estimated 80% compared to manual searching.
________________________________________
8. Conclusion
LeafLogic represents a perfect balance of mobile development and practical AI application. By choosing plant pathology over edibility, the project remains manageable for a two-person team while maintaining high technical standards and zero "life-safety" liability. It demonstrates proficiency in the full software development life cycle—from data curation and model training to front-end UI design and API integration.
