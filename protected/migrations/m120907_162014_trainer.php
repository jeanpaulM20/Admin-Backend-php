<?php
class m120907_162014_trainer extends CDbMigration
{
    public function up()
    {
    	if (!$this->getDbConnection()->getSchema()->getTable('tbl_trainer')) {
        	$this->createTable('tbl_trainer', array(
				'id' => 'pk',
				'surname' => 'string NULL',
				'name' => 'string NULL',
				'e_mail' => 'string NULL',
				'phone' => 'string NULL',
				'mobile' => 'string NULL',
				'foto' => 'string NULL',
				'active' => 'boolean NULL',
				'published' => 'boolean NULL',
        	), 'ENGINE=InnoDB DEFAULT CHARSET=utf8');

			
			
			
			
				if (!$this->getDbConnection()->getSchema()->getTable('tbl_trainer_location')) {
	$this->createTable('tbl_trainer_location', array(
		'trainer_id' => 'integer NOT NULL',
		'location_id' => 'integer NOT NULL',
		'PRIMARY KEY (trainer_id, location_id)',
	), 'ENGINE=InnoDB DEFAULT CHARSET=utf8');
}

	        }

        
    }
 
    public function down()
    {
    	if ($this->getDbConnection()->getSchema()->getTable('tbl_trainer')) {
        	$this->dropTable('tbl_trainer');
        }
    }
}