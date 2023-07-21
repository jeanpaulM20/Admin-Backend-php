<?php
class m120907_162014_client extends CDbMigration
{
    public function up()
    {
    	if (!$this->getDbConnection()->getSchema()->getTable('tbl_client')) {
        	$this->createTable('tbl_client', array(
				'id' => 'pk',
				'clientid' => 'string NULL',
				'clientpasscode' => 'string NULL',
				'surname' => 'string NULL',
				'name' => 'string NULL',
				'birthday' => 'date NULL',
				'e_mail' => 'string NULL',
				'phone' => 'string NULL',
				'mobile' => 'string NULL',
				'foto' => 'string NULL',
				'active' => 'boolean NULL',
				
        	), 'ENGINE=InnoDB DEFAULT CHARSET=utf8');

			
			
				
			
			
			
			
				if (!$this->getDbConnection()->getSchema()->getTable('tbl_trainer_client')) {
	$this->createTable('tbl_trainer_client', array(
		'trainer_id' => 'integer NOT NULL',
		'client_id' => 'integer NOT NULL',
		'PRIMARY KEY (trainer_id, client_id)',
	), 'ENGINE=InnoDB DEFAULT CHARSET=utf8');
}

			if (!$this->getDbConnection()->getSchema()->getTable('tbl_content_client')) {
	$this->createTable('tbl_content_client', array(
		'content_id' => 'integer NOT NULL',
		'client_id' => 'integer NOT NULL',
		'PRIMARY KEY (content_id, client_id)',
	), 'ENGINE=InnoDB DEFAULT CHARSET=utf8');
}

	        }

        
    }
 
    public function down()
    {
    	if ($this->getDbConnection()->getSchema()->getTable('tbl_client')) {
        	$this->dropTable('tbl_client');
        }
    }
}