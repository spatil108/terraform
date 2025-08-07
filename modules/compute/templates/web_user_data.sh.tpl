#!/bin/bash
# LAMP Stack Installation Script

# Update system packages
yum update -y

# Install Apache
yum install -y httpd
systemctl start httpd
systemctl enable httpd

# Install PHP and extensions
amazon-linux-extras enable php7.4
yum clean metadata
yum install -y php php-cli php-mysqlnd php-pdo php-fpm php-json php-gd
yum install -y mysql

# Install AWS CloudWatch agent
yum install -y amazon-cloudwatch-agent

# Configure CloudWatch agent
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'EOF'
{
    "agent": {
        "metrics_collection_interval": 60,
        "run_as_user": "root"
    },
    "metrics": {
        "metrics_collected": {
            "disk": {
                "measurement": ["used_percent"],
                "metrics_collection_interval": 60,
                "resources": ["/"]
            },
            "mem": {
                "measurement": ["mem_used_percent"],
                "metrics_collection_interval": 60
            }
        }
    }
}
EOF

# Start CloudWatch agent
systemctl start amazon-cloudwatch-agent
systemctl enable amazon-cloudwatch-agent

# Create application directory
mkdir -p /var/www/html/app

# Create index.php (Chat Display Page)
cat > /var/www/html/index.php << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Feedback Dashboard</title>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/5.15.4/css/all.min.css">
    <style>
        body { 
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            margin: 0;
            padding: 20px;
            background-color: #f5f5f5;
        }
        .chat-container {
            max-width: 1000px;
            margin: 0 auto;
            background: white;
            padding: 20px;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        .header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 20px;
            border-bottom: 2px solid #eee;
            padding-bottom: 10px;
        }
        .submit-btn {
            background-color: #4CAF50;
            color: white;
            padding: 10px 20px;
            border: none;
            border-radius: 5px;
            text-decoration: none;
            transition: background-color 0.3s;
        }
        .submit-btn:hover {
            background-color: #45a049;
        }
        .message {
            background: #fff;
            padding: 15px;
            margin: 10px 0;
            border-radius: 8px;
            border: 1px solid #e0e0e0;
            transition: transform 0.2s;
        }
        .message:hover {
            transform: translateX(5px);
            box-shadow: 0 2px 5px rgba(0,0,0,0.1);
        }
        .timestamp {
            color: #666;
            font-size: 0.8em;
            margin-top: 5px;
        }
        .stars {
            color: #ffd700;
            margin: 5px 0;
        }
        .message-content {
            margin: 10px 0;
        }
        #loading {
            text-align: center;
            padding: 20px;
            display: none;
        }
    </style>
    <script src="https://code.jquery.com/jquery-3.6.0.min.js"></script>
    <script>
        function loadMessages() {
            $.ajax({
                url: 'get_messages.php',
                success: function(data) {
                    $('#messages').html(data);
                }
            });
        }

        $(document).ready(function() {
            loadMessages();
            setInterval(loadMessages, 5000);
        });
    </script>
</head>
<body>
    <div class="chat-container">
        <div class="header">
            <h1>Feedback Dashboard</h1>
            <a href="feedback.php" class="submit-btn">Submit Feedback</a>
        </div>
        <div id="loading">Loading messages...</div>
        <div id="messages"></div>
    </div>
</body>
</html>
EOF

# Create get_messages.php
cat > /var/www/html/get_messages.php << 'EOF'
<?php
$host = "${db_host}";
$username = "${db_username}";
$password = "${db_password}";
$database = "${db_name}";

try {
    $conn = new PDO("mysql:host=$host;dbname=$database", $username, $password);
    $conn->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    $stmt = $conn->query("SELECT * FROM feedback ORDER BY created_at DESC");
    while($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
        echo '<div class="message">';
        echo '<div class="stars">';
        $rating = $row['rating'];
        for($i = 1; $i <= 5; $i++) {
            echo '<i class="fas fa-star' . ($i <= $rating ? '' : '-o') . '"></i>';
        }
        echo ' (' . $rating . '/5)';
        echo '</div>';
        echo '<div class="message-content">' . htmlspecialchars($row['message']) . '</div>';
        echo '<div class="timestamp">' . $row['created_at'] . '</div>';
        echo '</div>';
    }
} catch(PDOException $e) {
    echo "Connection failed: " . $e->getMessage();
}
?>
EOF

# Create feedback.php
cat > /var/www/html/feedback.php << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Submit Feedback</title>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/5.15.4/css/all.min.css">
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            margin: 0;
            padding: 20px;
            background-color: #f5f5f5;
        }
        .form-container {
            max-width: 600px;
            margin: 0 auto;
            background: white;
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        .header {
            margin-bottom: 20px;
            border-bottom: 2px solid #eee;
            padding-bottom: 10px;
        }
        textarea {
            width: 100%;
            height: 150px;
            padding: 12px;
            border: 1px solid #ddd;
            border-radius: 4px;
            margin: 10px 0;
            font-family: inherit;
            resize: vertical;
        }
        .submit-btn {
            background-color: #4CAF50;
            color: white;
            padding: 12px 24px;
            border: none;
            border-radius: 5px;
            cursor: pointer;
            font-size: 16px;
            transition: background-color 0.3s;
        }
        .submit-btn:hover {
            background-color: #45a049;
        }
        .star-rating {
            margin: 20px 0;
        }
        .star-rating input {
            display: none;
        }
        .star-rating label {
            font-size: 30px;
            color: #ddd;
            cursor: pointer;
            transition: color 0.2s;
        }
        .star-rating label:hover,
        .star-rating label:hover ~ label,
        .star-rating input:checked ~ label {
            color: #ffd700;
        }
        .back-link {
            color: #666;
            text-decoration: none;
            display: inline-block;
            margin-bottom: 20px;
        }
        .back-link:hover {
            color: #333;
        }
    </style>
</head>
<body>
    <div class="form-container">
        <a href="index.php" class="back-link">← Back to Dashboard</a>
        <div class="header">
            <h1>Submit Your Feedback</h1>
        </div>
        <form method="POST" action="submit_feedback.php">
            <div class="star-rating">
                <input type="radio" id="star5" name="rating" value="5" required>
                <label for="star5" class="fas fa-star"></label>
                <input type="radio" id="star4" name="rating" value="4">
                <label for="star4" class="fas fa-star"></label>
                <input type="radio" id="star3" name="rating" value="3">
                <label for="star3" class="fas fa-star"></label>
                <input type="radio" id="star2" name="rating" value="2">
                <label for="star2" class="fas fa-star"></label>
                <input type="radio" id="star1" name="rating" value="1">
                <label for="star1" class="fas fa-star"></label>
            </div>
            <textarea name="message" placeholder="Please share your feedback here..." required></textarea>
            <button type="submit" class="submit-btn">Submit Feedback</button>
        </form>
    </div>
</body>
</html>
EOF

# Create submit_feedback.php
cat > /var/www/html/submit_feedback.php << 'EOF'
<?php
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $host = "${db_host}";
    $username = "${db_username}";
    $password = "${db_password}";
    $database = "${db_name}";

    try {
        $conn = new PDO("mysql:host=$host;dbname=$database", $username, $password);
        $conn->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
        
        $stmt = $conn->prepare("INSERT INTO feedback (message, rating, created_at) VALUES (?, ?, NOW())");
        $stmt->execute([$_POST['message'], $_POST['rating']]);
        
        header("Location: thank_you.php");
        exit();
    } catch(PDOException $e) {
        echo "Error: " . $e->getMessage();
    }
}
?>
EOF

# Create thank_you.php
cat > /var/www/html/thank_you.php << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Thank You!</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            margin: 0;
            padding: 20px;
            background-color: #f5f5f5;
            text-align: center;
        }
        .thank-you-container {
            max-width: 600px;
            margin: 50px auto;
            background: white;
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        .thank-you-icon {
            font-size: 50px;
            color: #4CAF50;
            margin-bottom: 20px;
        }
        .back-btn {
            display: inline-block;
            background-color: #4CAF50;
            color: white;
            padding: 10px 20px;
            text-decoration: none;
            border-radius: 5px;
            margin-top: 20px;
            transition: background-color 0.3s;
        }
        .back-btn:hover {
            background-color: #45a049;
        }
    </style>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/5.15.4/css/all.min.css">
</head>
<body>
    <div class="thank-you-container">
        <div class="thank-you-icon">
            <i class="fas fa-check-circle"></i>
        </div>
        <h1>Thank You for Your Feedback!</h1>
        <p>Your feedback has been successfully submitted and will help us improve our services.</p>
        <a href="index.php" class="back-btn">Return to Dashboard</a>
    </div>
</body>
</html>
EOF

# Update database initialization script
cat > /var/www/html/app/init_db.php << 'EOF'
<?php
$host = "${db_host}";
$username = "${db_username}";
$password = "${db_password}";
$database = "${db_name}";

try {
    $conn = new PDO("mysql:host=$host;dbname=$database", $username, $password);
    $conn->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    // Create feedback table with rating column
    $sql = "CREATE TABLE IF NOT EXISTS feedback (
        id INT AUTO_INCREMENT PRIMARY KEY,
        message TEXT NOT NULL,
        rating INT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )";
    $conn->exec($sql);
    echo "Database initialized successfully";
} catch(PDOException $e) {
    echo "Error: " . $e->getMessage();
}
?>
EOF

# More comprehensive health.php
cat > /var/www/html/health.php << 'EOF'
<?php
header('Content-Type: application/json');

$status = array(
    'status' => 'healthy',
    'timestamp' => date('Y-m-d H:i:s'),
    'checks' => array(
        'database' => 'ok',
        'disk_space' => 'ok',
        'memory' => 'ok'
    )
);

try {
    // Database check
    $host = "${db_host}";
    $username = "${db_username}";
    $password = "${db_password}";
    $database = "${db_name}";

    $conn = new PDO("mysql:host=$host;dbname=$database", $username, $password);
    $conn->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
} catch(PDOException $e) {
    $status['status'] = 'unhealthy';
    $status['checks']['database'] = 'failed';
}

// Disk space check
$disk_free_space = disk_free_space("/");
if ($disk_free_space < 1024 * 1024 * 100) { // Less than 100MB
    $status['status'] = 'unhealthy';
    $status['checks']['disk_space'] = 'low';
}

// Memory check
$memory_limit = ini_get('memory_limit');
if (intval($memory_limit) < 128) { // Less than 128M
    $status['status'] = 'unhealthy';
    $status['checks']['memory'] = 'low';
}

// Set appropriate HTTP status code
if ($status['status'] === 'healthy') {
    http_response_code(200);
} else {
    http_response_code(500);
}

// Output JSON response
echo json_encode($status, JSON_PRETTY_PRINT);
?>
EOF

# Set permissions
chown -R apache:apache /var/www/html
chmod -R 755 /var/www/html

# Restart Apache
systemctl restart httpd

# Initialize database
php /var/www/html/app/init_db.php

# Tag instance
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)

aws ec2 create-tags \
    --region $REGION \
    --resources $INSTANCE_ID \
    --tags Key=Name,Value=${environment}-web-server